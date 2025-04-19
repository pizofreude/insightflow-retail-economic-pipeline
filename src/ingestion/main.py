import os
import logging
import io
from datetime import datetime

import requests
import pandas as pd
import boto3
from botocore.exceptions import ClientError

# --- Configuration ---
# URLs for the datasets
# data.gov.my OpenAPI endpoints
API_BASE_URL = "https://api.data.gov.my/data-catalogue"
# Direct Parquet download URL
DIRECT_PARQUET_URL_IOWRT_3D = "https://storage.dosm.gov.my/iowrt/iowrt_3d.parquet"

# S3 Configuration - Bucket name is read from environment variable
TARGET_BUCKET = os.environ.get("TARGET_BUCKET") # Set this in Batch Job Definition
S3_RAW_PREFIX = "raw" # Base prefix for raw data

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

def fetch_api_data(dataset_id: str) -> pd.DataFrame | None:
    """Fetches data from the data.gov.my OpenAPI."""
    url = f"{API_BASE_URL}?id={dataset_id}"
    logger.info(f"Fetching data from API: {url}")
    try:
        response = requests.get(url, timeout=60) # Add timeout
        response.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)
        data = response.json()
        if data:
            df = pd.DataFrame(data)
            logger.info(f"Successfully fetched {len(df)} records for dataset '{dataset_id}'.")
            # Ensure date column is datetime type
            if 'date' in df.columns:
                df['date'] = pd.to_datetime(df['date'], errors='coerce')
            return df
        else:
            logger.warning(f"No data returned from API for dataset '{dataset_id}'.")
            return None
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching data from API for dataset '{dataset_id}': {e}")
        return None
    except Exception as e:
        logger.error(f"An unexpected error occurred while fetching API data for '{dataset_id}': {e}")
        return None

def download_parquet_data(url: str) -> pd.DataFrame | None:
    """Downloads a Parquet file directly from a URL."""
    logger.info(f"Downloading Parquet data from: {url}")
    try:
        # Use pandas to read directly (handles potential redirects and errors)
        df = pd.read_parquet(url)
        logger.info(f"Successfully downloaded {len(df)} records from {url}.")
         # Ensure date column is datetime type
        if 'date' in df.columns:
            df['date'] = pd.to_datetime(df['date'], errors='coerce')
        return df
    except Exception as e:
        logger.error(f"Error downloading Parquet data from {url}: {e}")
        return None

def df_to_parquet_bytes(df: pd.DataFrame) -> bytes | None:
    """Converts a Pandas DataFrame to Parquet format in memory."""
    logger.info("Converting DataFrame to Parquet format in memory.")
    try:
        out_buffer = io.BytesIO()
        # Use pyarrow engine (recommended), requires pyarrow installed
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

def process_and_upload(df: pd.DataFrame, dataset_name: str, date_column: str = 'date'):
    """Processes DataFrame rows and uploads them as individual Parquet files partitioned by date."""
    if df is None or df.empty:
        logger.warning(f"DataFrame for dataset '{dataset_name}' is empty or None. Skipping upload.")
        return

    if date_column not in df.columns:
        logger.error(f"Date column '{date_column}' not found in DataFrame for dataset '{dataset_name}'. Cannot partition.")
        return

    # Drop rows where the date column is NaT after conversion
    df = df.dropna(subset=[date_column])

    logger.info(f"Processing and uploading {len(df)} records for dataset '{dataset_name}'...")

    success_count = 0
    error_count = 0

    # Determine partition frequency based on dataset
    if dataset_name == 'fuelprice':
        partition_format = "%Y/%m/%d" # Daily for fuel price
        filename_date_format = "%Y-%m-%d"
    else: # Assume monthly for trade data
        partition_format = "%Y/%m" # Monthly for trade data
        filename_date_format = "%Y-%m"

    # Group by partition key to potentially upload multiple records per file if dates are identical
    # Or iterate row by row if daily/unique partitioning is desired
    # For simplicity here, let's assume we upload one file per unique date partition found

    unique_dates = df[date_column].dt.to_period('M' if partition_format == "%Y/%m" else 'D').unique()

    for period in unique_dates:
        year_str = f"{period.year:04d}"
        month_str = f"{period.month:02d}"

        if partition_format == "%Y/%m/%d":
            day_str = f"{period.day:02d}"
            partition_key = f"year={year_str}/month={month_str}/day={day_str}"
            file_date_str = period.strftime(filename_date_format)
            df_subset = df[df[date_column].dt.to_period('D') == period]
        else: # Monthly
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

    # 1. Headline Wholesale & Retail Trade (iowrt) - API JSON -> Parquet
    logger.info("--- Processing Headline Trade (iowrt) ---")
    df_iowrt = fetch_api_data("iowrt")
    if df_iowrt is not None:
        process_and_upload(df_iowrt, "iowrt", "date")
    else:
        logger.error("Failed to fetch or process Headline Trade data.")

    # 2. Detailed Wholesale & Retail Trade (iowrt_3d) - Direct Parquet Download
    logger.info("--- Processing Detailed Trade (iowrt_3d) ---")
    df_iowrt_3d = download_parquet_data(DIRECT_PARQUET_URL_IOWRT_3D)
    if df_iowrt_3d is not None:
         # Data is already Parquet, but we process for consistent partitioning/upload
        process_and_upload(df_iowrt_3d, "iowrt_3d", "date")
    else:
        logger.error("Failed to download or process Detailed Trade data.")

    # 3. Fuel Prices (fuelprice) - API JSON -> Parquet
    logger.info("--- Processing Fuel Prices (fuelprice) ---")
    df_fuelprice = fetch_api_data("fuelprice")
    if df_fuelprice is not None:
        process_and_upload(df_fuelprice, "fuelprice", "date")
    else:
        logger.error("Failed to fetch or process Fuel Price data.")

    logger.info("Ingestion script finished.")

