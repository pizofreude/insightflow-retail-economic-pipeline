The data modeling strategy focuses on transforming the raw source data into a well-structured analytical layer using dbt, suitable for querying with Athena and feeding BI dashboards. A star schema is chosen for its simplicity and effectiveness for analytical queries.

1. **Sources:**
    - Define dbt sources referencing the raw Parquet files landed by the ingestion process in the `raw` S3 bucket prefix. Initial Athena tables for these raw sources will be created/updated by an AWS Glue Crawler.
    - Sources: `raw_iowrt` (Headline Trade), `raw_iowrt_3d` (Detailed Trade), `raw_fuelprice`.
    - Include the **MSIC lookup data** (provided in `msic.txt`) as a **dbt seed file** (`msic_lookup.csv`) to decode the 3-digit group codes.
2. **`Staging Models (models/staging/stg_*.sql):`** 
    - One model per source/seed (e.g., `stg_iowrt`, `stg_iowrt_3d`, `stg_fuelprice`, `stg_msic_lookup`).
    - **Purpose:** Perform initial cleaning, standardization, and preparation.
    - **Transformations:**
        - Select necessary columns.\
        - Rename columns to a consistent snake_case convention (e.g., `sales_value_rm_mil`, `volume_index`, `ron95_price`, `ron97_price`, `diesel_price`, `group_code`, `group_desc_en`, `group_desc_bm`).
        - Cast data types (dates, floats, strings).
        - Filter records (e.g., keep only `series='abs'` for trade, `series_type='level'` for fuel prices).
        - Basic null handling if necessary.
        - For `stg_msic_lookup`, filter for the relevant 3-digit group codes and their descriptions.
3. **`Intermediate Models (models/intermediate/int_*.sql):`** 
    - **Purpose:** Handle more complex transformations and pre-aggregation needed before creating the final mart models.
    - **`int_fuelprice_monthly`**: Aggregate the weekly `stg_fuelprice` data to a monthly level. This involves calculating the average price for RON95, RON97, and Diesel for each month. Create a `year_month` key (e.g., 'YYYY-MM') for joining.
    - **`(Optional) int_trade_unioned:`** If headline (`stg_iowrt`) and detailed (`stg_iowrt_3d`) trade data need combining or consistent structuring before the fact table, this model can handle it. It might involve adding a placeholder `group_code` (e.g., 'Overall') to the headline data.
4. **`Mart Models (models/marts/*.sql):`**
    - **Purpose:** Create the final, analysis-ready tables in a star schema.
    - **`dim_date`**: A dimension table built from distinct dates across the sources. Contains `date_key`, `full_date`, `year`, `month`, `year_month`, `quarter`, etc.
    - **`dim_msic_group`**: Dimension table for retail trade groups.
        - **Source:** Built from `stg_msic_lookup` (derived from the seed file).
        - **Columns:** Contains `msic_group_key` (surrogate key), `group_code` (natural key, 3-digit), `group_desc_en` (English description), `group_desc_bm` (Malay description).
    - **`fct_retail_sales_monthly`**: The primary fact table.
        - **Grain:** One row per MSIC group (or 'Overall') per month.
        - **Foreign Keys:** `date_key` (linking to `dim_date` on month start date), `msic_group_key` (linking to `dim_msic_group` on `group_code`).
        - **Measures:** `sales_value_rm_mil`, `volume_index` (from `stg_iowrt_3d` or `int_trade_unioned`), `avg_ron95_price`, `avg_ron97_price`, `avg_diesel_price` (joined from `int_fuelprice_monthly` using `year_month`).
        - **Materialization:** Configured as `table` in dbt to persist results in the `processed` S3 bucket prefix.
5. **Data Warehouse Optimization (S3/Athena):**
    - **Partitioning:** The `fct_retail_sales_monthly` table data in S3 will be **partitioned by year and month** (e.g., `s3://.../processed/fct_retail_sales_monthly/year=YYYY/month=MM/`).
        - **Rationale:** This is crucial for Athena performance and cost-effectiveness. Analytical queries often filter by time periods (e.g., last 6 months, specific year). Partitioning allows Athena to scan only the relevant S3 prefixes (folders) containing the data for the specified partitions, drastically reducing the amount of data scanned, query runtime, and cost.
    - **File Format:** Parquet is used throughout (raw and processed) for its columnar storage benefits, compression, and query performance with Athena.
6. **Testing & Documentation (dbt):**
    - Implement dbt tests (schema tests like `not_null`, `unique`, `accepted_values`, `relationships`, and potentially custom data tests) on key columns in staging and mart models to ensure data quality.
    - Utilize dbt's documentation generation features to create a data catalog describing models, columns, and relationships.
  
The Entity Relational Diagram (ERD) for the final Data Warehouse is illustrated as follows:

<center>

![ERD](../images/Entity-Relational-Diagram-(ERD)-InsightFlow.svg)

</center>

## Troubleshooting

## Commonly used dbt commands:

Here are some commonly used dbt commands for managing a dbt project especially in troubleshooting in case of errors in Kestra Workflow.

* `dbt deps`: Installs the required packages and dependencies.
* `dbt debug`: Checks the dbt project's configuration and dependencies.
* `dbt init`: Initialize a new dbt project.
* `dbt defer`: Defers compilation of a model, allowing you to break up long-running models.
* `dbt run`: Runs all compiled SQL scripts in the project.
* `dbt test`: Tests all models in the project.
* `dbt build`: Runs `dbt seed`, `dbt run`, `dbt test`, and `dbt snapshot`. together. Builds and tests all selected resources (models, seeds, snapshots, tests).
* `dbt seed`: Loads data from CSV files into the database.
* `dbt docs generate`: Generates documentation for the project.
* `dbt docs serve`: Serves the generated documentation on a webserver.

For more information, refer to the dbt [documentation](https://docs.getdbt.com/docs/commands).