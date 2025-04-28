import os
import logging
import io
import pandas as pd
import boto3
from botocore.exceptions import ClientError

# --- Configuration ---
# Direct Parquet download URLs
DIRECT_PARQUET_URL_IOWRT = "https://storage.dosm.gov.my/iowrt/iowrt.parquet"
DIRECT_PARQUET_URL_IOWRT_3D = "https://storage.dosm.gov.my/iowrt/iowrt_3d.parquet"
DIRECT_PARQUET_URL_FUELPRICE = "https://storage.data.gov.my/commodities/fuelprice.parquet"

# S3 Configuration - Bucket name is read from environment variable
TARGET_BUCKET = os.environ.get("TARGET_BUCKET")  # Set this in Batch Job Definition
S3_RAW_PREFIX = "raw"  # Base prefix for raw data

# Logging Configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# AWS S3 Client
s3_client = boto3.client("s3")

# --- Helper Functions ---

def download_parquet_data(url: str) -> pd.DataFrame | None:
    """Downloads a Parquet file directly from a URL."""
    logger.info(f"Downloading Parquet data from: {url}")
    try:
        df = pd.read_parquet(url)
        logger.info(f"Successfully downloaded {len(df)} records from {url}.")
        return df
    except Exception as e:
        logger.error(f"Error downloading Parquet data from {url}: {e}")
        return None

def df_to_parquet_bytes(df: pd.DataFrame) -> bytes | None:
    """Converts a Pandas DataFrame to Parquet format in memory."""
    logger.info("Converting DataFrame to Parquet format in memory.")
    try:
        # Ensure 'ymd_date' is in datetime format
        if 'ymd_date' in df.columns and not pd.api.types.is_datetime64_any_dtype(df['ymd_date']):
            logger.error("'ymd_date' column is not in datetime format. Conversion failed.")
            return None

        out_buffer = io.BytesIO()
        df.to_parquet(out_buffer, index=False, engine='pyarrow', compression='snappy')
        logger.info("Conversion to Parquet bytes successful.")
        return out_buffer.getvalue()
    except Exception as e:
        logger.error(f"Error converting DataFrame to Parquet bytes: {e}")
        return None

def upload_to_s3(data_bytes: bytes, bucket: str, s3_key: str) -> bool:
    """Uploads bytes data to a specific S3 key."""
    logger.info(f"Uploading data to s3://{bucket}/{s3_key}")
    try:
        s3_client.put_object(Bucket=bucket, Key=s3_key, Body=data_bytes)
        logger.info(f"Successfully uploaded data to s3://{bucket}/{s3_key}")
        return True
    except ClientError as e:
        logger.error(f"Failed to upload data to s3://{bucket}/{s3_key}: {e}")
        return False
    except Exception as e:
        logger.error(f"An unexpected error occurred during S3 upload to s3://{bucket}/{s3_key}: {e}")
        return False


def process_and_upload(df: pd.DataFrame, dataset_name: str, date_column: str = 'ymd_date'):
    """Processes DataFrame rows and uploads them as individual Parquet files partitioned by date."""
    # Handle column renaming for specific datasets
    if dataset_name == "iowrt":
        if "date" in df.columns:
            df.rename(columns={"date": "ymd_date"}, inplace=True)
            logger.info(f"Renamed 'date' column to 'ymd_date' for {dataset_name} dataset.")
        else:
            logger.warning(f"'date' column not found in {dataset_name} dataset. Skipping rename.")
            return

    elif dataset_name == "iowrt_3d":
        if "date" in df.columns:
            df.rename(columns={"date": "ymd_date"}, inplace=True)
            logger.info(f"Renamed 'date' column to 'ymd_date' for {dataset_name} dataset.")
        else:
            logger.warning(f"'date' column not found in {dataset_name} dataset. Skipping rename.")
            return

        if "group" in df.columns:
            df.rename(columns={"group": "group_code"}, inplace=True)
            logger.info(f"Renamed 'group' column to 'group_code' for {dataset_name} dataset.")
        else:
            logger.warning(f"'group' column not found in {dataset_name} dataset. Skipping rename.")

    elif dataset_name == "fuelprice":
        # Use the data source's logic to handle the 'date' column
        if "date" in df.columns:
            df.rename(columns={"date": "ymd_date"}, inplace=True)
            logger.info(f"Renamed 'date' column to 'ymd_date' for {dataset_name} dataset.")
        else:
            logger.warning(f"'date' column not found in {dataset_name} dataset. Skipping rename.")
            return
    
        # Convert 'ymd_date' to datetime using the data source's approach
        if "ymd_date" in df.columns:
            logger.info(f"Sample 'ymd_date' values before conversion: {df['ymd_date'].head()}")
            try:
                df["ymd_date"] = pd.to_datetime(df["ymd_date"], errors='coerce')
                logger.info(f"Sample 'ymd_date' values after conversion: {df['ymd_date'].head()}")
                logger.info(f"Data type of 'ymd_date' column after conversion: {df['ymd_date'].dtype}")
            except Exception as e:
                logger.error(f"Error converting 'ymd_date' to datetime for {dataset_name}: {e}")
                return

    # Check if the date column exists after renaming
    if date_column not in df.columns:
        logger.error(f"Date column '{date_column}' not found in DataFrame for dataset '{dataset_name}'. Cannot partition.")
        return

    # Drop rows where the date column is NaT after conversion
    df = df.dropna(subset=[date_column])

    logger.info(f"Processing and uploading {len(df)} records for dataset '{dataset_name}'...")

    # Determine partition frequency based on dataset
    if dataset_name == 'fuelprice':
        partition_format = "%Y/%m/%d"  # Daily for fuel price
        filename_date_format = "%Y-%m-%d"
    else:  # Assume monthly for trade data
        partition_format = "%Y/%m"  # Monthly for trade data
        filename_date_format = "%Y-%m"

    # Ensure the 'ymd_date' column is in datetime format
    if not pd.api.types.is_datetime64_any_dtype(df[date_column]):
        logger.error(f"Column '{date_column}' is not in datetime format for dataset '{dataset_name}'. Skipping upload.")
        return

    # Generate unique dates for partitioning
    unique_dates = df[date_column].dt.to_period('M' if partition_format == "%Y/%m" else 'D').unique()

    success_count = 0
    error_count = 0

    for period in unique_dates:
        year_str = f"{period.year:04d}"
        month_str = f"{period.month:02d}"

        if partition_format == "%Y/%m/%d":
            day_str = f"{period.day:02d}"
            partition_key = f"year={year_str}/month={month_str}/day={day_str}"
            file_date_str = period.strftime(filename_date_format)
            df_subset = df[df[date_column].dt.to_period('D') == period]
        else:  # Monthly
            partition_key = f"year={year_str}/month={month_str}"
            file_date_str = period.strftime(filename_date_format)
            df_subset = df[df[date_column].dt.to_period('M') == period]

        if df_subset.empty:
            continue

        # Convert the subset DataFrame to Parquet bytes
        parquet_bytes = df_to_parquet_bytes(df_subset)

        if parquet_bytes:
            # Construct S3 key
            s3_key = f"{S3_RAW_PREFIX}/{dataset_name}/{partition_key}/{dataset_name}_{file_date_str}.parquet"

            # Upload to S3
            if upload_to_s3(parquet_bytes, TARGET_BUCKET, s3_key):
                success_count += len(df_subset)
            else:
                error_count += len(df_subset)
        else:
            error_count += len(df_subset)
            logger.error(f"Skipping upload for partition {partition_key} due to Parquet conversion error.")

    logger.info(f"Finished uploading for dataset '{dataset_name}'. Success: {success_count}, Errors: {error_count}")

# --- Main Execution ---
if __name__ == "__main__":
    logger.info("Starting ingestion script...")

    if not TARGET_BUCKET:
        logger.error("TARGET_BUCKET environment variable not set. Exiting.")
        exit(1)
    else:
        logger.info(f"Target S3 bucket: {TARGET_BUCKET}")

    # 1. Headline Wholesale & Retail Trade (iowrt)
    logger.info("--- Processing Headline Trade (iowrt) ---")
    df_iowrt = download_parquet_data(DIRECT_PARQUET_URL_IOWRT)
    if df_iowrt is not None:
        process_and_upload(df_iowrt, "iowrt", "ymd_date")
    else:
        logger.error("Failed to download or process Headline Trade data.")

    # 2. Detailed Wholesale & Retail Trade (iowrt_3d)
    logger.info("--- Processing Detailed Trade (iowrt_3d) ---")
    df_iowrt_3d = download_parquet_data(DIRECT_PARQUET_URL_IOWRT_3D)
    if df_iowrt_3d is not None:
        process_and_upload(df_iowrt_3d, "iowrt_3d", "ymd_date")
    else:
        logger.error("Failed to download or process Detailed Trade data.")

    # 3. Fuel Prices (fuelprice)
    logger.info("--- Processing Fuel Prices (fuelprice) ---")
    df_fuelprice = download_parquet_data(DIRECT_PARQUET_URL_FUELPRICE)
    if df_fuelprice is not None:
        process_and_upload(df_fuelprice, "fuelprice", "ymd_date")
    else:
        logger.error("Failed to download or process Fuel Price data.")

    logger.info("Ingestion script finished.")