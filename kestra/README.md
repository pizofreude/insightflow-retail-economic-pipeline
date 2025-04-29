
# Kestra – Workflow Orchestration for InsightFlow

The **Kestra** directory contains the workflow orchestration logic for the InsightFlow project. Kestra is used to automate and manage the end-to-end data pipeline, ensuring reliability, observability, and scalability. This README explains the purpose of Kestra in the project, provides an overview of the workflows, and guides you on how to replicate the setup.

---

## **Overview**

Kestra is a modern workflow orchestration platform that simplifies the management of complex workflows. In the InsightFlow project, Kestra orchestrates the following key tasks:

1. **Data Ingestion**: Submitting AWS Batch jobs to fetch raw data from public sources.
2. **Data Cataloging**: Running AWS Glue Crawlers to update the Glue Data Catalog.
3. **Data Transformation**: Executing dbt models to clean, normalize, and structure the data.
4. **Data Validation**: Running dbt tests to ensure data quality.
5. **Scheduling**: Automating the pipeline to run daily.

Below is a high-level visualization of the Kestra workflow:

![Kestra Workflow Orchestration](images/kestra-workflow-orchestration.png)


## **Workflow Details**

The workflow is defined in the file [`insightflow_prod_pipeline.yml`](flows/insightflow_prod_pipeline.yml). It consists of multiple tasks, each responsible for a specific part of the pipeline. Here's a breakdown of the key tasks:

### **1. Data Ingestion**
The workflow starts by submitting an AWS Batch job to ingest raw data into the S3 bucket `insightflow-prod-raw-data`. This is achieved using the following task:

```yaml
- id: submit_batch_ingestion_job_cli
  type: io.kestra.core.tasks.scripts.Bash
  commands:
    - |
      echo "Submitting AWS Batch Job..."
      JOB_DEF_NAME="insightflow-prod-ingestion-job-def"
      JOB_QUEUE_NAME="insightflow-prod-job-queue"
      TARGET_BUCKET_NAME="insightflow-prod-raw-data"
      AWS_REGION="ap-southeast-2"

      JOB_NAME="insightflow-ingestion-{{execution.id}}"
      JOB_OUTPUT=$(aws batch submit-job \
        --region "$AWS_REGION" \
        --job-name "$JOB_NAME" \
        --job-queue "$JOB_QUEUE_NAME" \
        --job-definition "$JOB_DEF_NAME" \
        --container-overrides '{
            "environment": [
              {"name": "TARGET_BUCKET", "value": "'"$TARGET_BUCKET_NAME"'"}
            ]
          }')

      JOB_ID=$(echo "$JOB_OUTPUT" | grep -o '"jobId": "[^"]*' | awk -F'"' '{print $4}')
      echo "Submitted Job ID: $JOB_ID"
```

---

### **2. Data Cataloging**
Once the raw data is ingested, the workflow triggers an AWS Glue Crawler to update the Glue Data Catalog. This ensures that the latest data is available for querying in Athena.

```yaml
- id: start_glue_crawler_cli
  type: io.kestra.core.tasks.scripts.Bash
  commands:
    - |
      echo "Starting AWS Glue Crawler..."
      CRAWLER_NAME="insightflow-prod-raw-data-crawler"
      AWS_REGION="ap-southeast-2"

      aws glue start-crawler --region $AWS_REGION --name "$CRAWLER_NAME"
      echo "Crawler $CRAWLER_NAME started."
```

---

### **3. Data Transformation**
After the data is cataloged, the workflow runs dbt models to transform the raw data into an analysis-ready format. This includes syncing dbt files, installing dependencies, and running the models.

```yaml
- id: dbt_run
  type: io.kestra.plugin.dbt.cli.DbtCLI
  commands:
    - dbt run --target prod
    namespaceFiles:
      enabled: false
    containerImage: pizofreude/kestra-dbt-athena:latest
```

---

### **4. Data Validation**
To ensure data quality, the workflow runs dbt tests on the transformed data. Any issues are logged for further investigation.

```yaml
- id: dbt_test
  type: io.kestra.plugin.dbt.cli.DbtCLI
  commands:
    - dbt test --target prod
    namespaceFiles:
      enabled: false
    containerImage: pizofreude/kestra-dbt-athena:latest
```

---

### **5. Scheduling**
The workflow is scheduled to run daily at 5:00 AM UTC using Kestra's scheduling feature.

```yaml
triggers:
  - id: daily_schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 5 * * *"
```

---

## **Execution Flow**

The following Gantt chart illustrates the execution flow of the Kestra workflow, showing the sequence and dependencies of tasks:

![Kestra Workflow Gantt Chart](images/kestra-workflow-orchestration-gantt.png)

---

## **How to Replicate This Setup**

Follow these steps to replicate the Kestra workflow for your own project:

### **1. Install Kestra**
- Refer to the [Kestra documentation](https://kestra.io/docs/) for installation instructions.
- For this project, Kestra is deployed on an EC2 instance using Docker Compose. Terraform provisions the infrastructure and sets up Kestra automatically.

### **2. Deploy the Workflow**
- Access the Kestra UI using the URL provided by Terraform after deployment.
- Navigate to the "Flows" section and click "Create".
- Copy the contents of [`insightflow_prod_pipeline.yml`](flows/insightflow_prod_pipeline.yml) into the editor.
- Save the workflow.

### **3. Execute the Workflow**
- Go to the "Flows" section in the Kestra UI.
- Select the workflow (e.g., `prod.pipelines.insightflow_prod_pipeline`).
- Click the "Execute" button (▶️) to start the workflow.
- Monitor the progress in the "Executions" tab.

### **4. Monitor and Debug**
- Use the Kestra UI to view logs and metrics for each task.
- Check AWS CloudWatch for logs related to AWS Batch and Glue Crawlers.

---

## **Key Benefits of Using Kestra**

1. **Automation**: Kestra automates the entire pipeline, reducing manual intervention and ensuring consistency.
2. **Error Handling**: Built-in retry mechanisms and detailed logs make it easy to identify and resolve issues.
3. **Scalability**: Kestra can handle large-scale workflows with multiple tasks and dependencies.
4. **Flexibility**: The declarative YAML syntax allows for easy customization and extension of workflows.

---

## **Conclusion**

Kestra plays a critical role in orchestrating the InsightFlow pipeline, ensuring that data ingestion, transformation, and validation are automated and reliable. By following the steps outlined in this README, you can replicate the workflow for your own projects and take advantage of Kestra's powerful orchestration capabilities.

For more details, refer to the [Kestra documentation](https://kestra.io/docs/) or explore the workflow definition in [`insightflow_prod_pipeline.yml`](flows/insightflow_prod_pipeline.yml).