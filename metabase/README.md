```markdown
# Metabase Setup for InsightFlow

This guide walks you through setting up Metabase locally using Docker and connecting it to your Amazon Athena data. Metabase is a powerful tool for exploring and visualizing data, and this setup will allow you to analyze your `InsightFlow` pipeline data.

---

## **Step 1: Run Metabase Locally Using Docker**

1. **Ensure Docker is Running**: Make sure Docker Desktop (or Docker Engine) is installed and running on your machine.
2. **Open Terminal**: Use your preferred terminal (Git Bash, Command Prompt, PowerShell, etc.).
3. **Run Metabase Container**: Execute the following command to pull the latest Metabase image and run it as a container:
   ```bash
   docker run -d -p 3000:3000 --name metabase metabase/metabase
   ```
   - `-d`: Runs the container in detached mode (background).
   - `-p 3000:3000`: Maps port 3000 on your host to port 3000 in the container.
   - `--name metabase`: Assigns a name to the container.
   - `metabase/metabase`: The official Metabase Docker image.

4. **Wait for Startup**: Allow the container a minute or two to start. Check its status with:
   ```bash
   docker ps
   ```
   View logs if needed:
   ```bash
   docker logs metabase
   ```

5. **Access Metabase UI**: Open your browser and navigate to:
   ```
   http://localhost:3000
   ```

---

## **Step 2: Initial Metabase Setup**

1. **Language**: Select your preferred language.
2. **Account Creation**: Create an admin account with your email, name, and password.
3. **Add Your Data**: When prompted,  **select"Amazon Athena"** as the database type.

---

## **Step 3: Configure Athena Connection in Metabase**

1. **Display Name**: Enter a name for the connection (e.g., `InsightFlow Dev Athena`).
2. **AWS Region**: Specify the region where your Athena database and S3 buckets are located (e.g., `ap-southeast-2`).
3. **S3 Staging Directory**: Provide the full S3 URI for the staging directory:
   ```
   s3://insightflow-dev-processed-data/dbt-athena-results/
   ```
   Ensure this bucket exists and the path is correct.
4. **AWS Access Key ID & Secret Access Key**:
   - **Option 1 (Local Setup)**: Provide your AWS Access Key ID and Secret Access Key.
   - **Option 2 (EC2 Instance)**: If Metabase is running on an EC2 instance with an IAM role, leave these fields blank to use the instance profile.
   - **Permissions**: Ensure the IAM user or role has the following permissions:
     - **Athena**: `athena:StartQueryExecution`, `athena:GetQueryResults`, etc.
     - **Glue**: `glue:GetDatabase`, `glue:GetTables`, etc.
     - **S3**: `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` for the staging directory and data bucket.
5. **Database Name (Optional)**: Leave blank to use the Glue Data Catalog.
6. **Workgroup (Optional)**: Specify your Athena workgroup if not using the default `primary`.
7. **Session Role ARN (Optional)**: Leave blank unless you need to assume a specific role.

---

## **Step 4: Save and Explore**

1. **Save the Connection**: Metabase will test the connection. If successful, you'll be redirected to the home page.
2. **Browse Data**:
   - Click **Browse Data** or the database icon.
   - Select your `awsdatacatalog` database.
   - Navigate to the `insightflow_dev` schema to view tables created by dbt (e.g., `fct_retail_sales_monthly`, `dim_date`, etc.).
3. **Ask Questions**: Use Metabase's query builder to explore and visualize your data.

---

## **Troubleshooting**

- **Metabase Not Starting**: Check the container logs:
  ```bash
  docker logs metabase
  ```
- **Connection Issues**: Verify your AWS credentials, S3 staging directory, and Athena permissions.
- **Data Not Visible**: Ensure your Glue Data Catalog is correctly configured and accessible.

---

You are now ready to explore and visualize your `InsightFlow` pipeline data using Metabase. Start building dashboards and uncover insights!
