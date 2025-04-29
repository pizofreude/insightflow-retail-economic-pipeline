# Ingestion Service – Docker Image for AWS Batch

This guide explains how to build a Docker image from the `Dockerfile` and `main.py` in this directory and push it to Amazon Elastic Container Registry (ECR). The image will be used by AWS Batch to run ingestion jobs.

---

## **Step 1: Prerequisites**

1. **Install Docker**:
   - Ensure Docker is installed and running on your system. You can download it from [Docker's official website](https://www.docker.com/).

2. **Install AWS CLI**:
   - Ensure the AWS CLI is installed and configured with the necessary permissions to push images to ECR.
   - Run `aws configure` to set up your AWS credentials.

3. **Create an ECR Repository**:
   - Create an ECR repository in AWS to store your Docker image:
     ```bash
     aws ecr create-repository --repository-name insightflow-ingestion
     ```
   - Note the repository URI from the output (e.g., `864899839546.dkr.ecr.ap-southeast-2.amazonaws.com/insightflow-ingestion`).

---

## **Step 2: Build the Docker Image**

1. **Navigate to the Directory**:
   - Open a terminal and navigate to the directory containing the `Dockerfile` and `main.py`:
     ```bash
     cd c:/workspace/insightflow-retail-economic-pipeline/src/ingestion
     ```

2. **Build the Docker Image**:
   - Use the `docker build` command to create the Docker image:
     ```bash
     docker build -t insightflow-ingestion:latest .
     ```
   - The `-t` flag assigns a tag (`insightflow-ingestion`) to the image.

---

## **Step 3: Authenticate Docker with ECR**

1. **Retrieve an Authentication **Token:
   - Use the AWS CLI to authenticate Docker with ECR:
     ```bash
     aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin 864899839546.dkr.ecr.ap-southeast-2.amazonaws.com
     ```
   - Replace `864899839546` with your AWS account ID.

---

## **Step 4: Tag the Docker Image**

1. **Tag the Image for ECR**:
   - Tag the Docker image with the ECR repository URI:
     ```bash
     docker tag insightflow-ingestion:latest 864899839546.dkr.ecr.ap-southeast-2.amazonaws.com/insightflow-ingestion:latest
     ```

---

## **Step 5: Push the Docker Image to ECR**

1. **Push the Image**:
   - Push the tagged image to your ECR repository:
     ```bash
     docker push 864899839546.dkr.ecr.ap-southeast-2.amazonaws.com/insightflow-ingestion:latest
     ```

---

## **Step 6: Verify the Image in ECR**

1. **Check the ECR Repository**:
   - Go to the AWS Management Console.
   - Navigate to **ECR** > **Repositories** > `insightflow-ingestion`.
   - Verify that the image has been successfully pushed.

---

## **Step 7: Use the Image**

1. **Run the Image Locally (Optional)**:
   - Test the image locally to ensure it works as expected:
     ```bash
     docker run --rm insightflow-ingestion
     ```

2. **Deploy the Image**:
   - Use the image in AWS Batch by referencing the ECR URI in your Batch job definition.

---

## **Summary of Commands**

```bash
# Navigate to the directory
cd c:/workspace/insightflow-retail-economic-pipeline/src/ingestion

# Build the Docker image
docker build -t insightflow-ingestion:latest .

# Authenticate Docker with ECR
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin 864899839546.dkr.ecr.ap-southeast-2.amazonaws.com

# Tag the Docker image
docker tag insightflow-ingestion:latest 864899839546.dkr.ecr.ap-southeast-2.amazonaws.com/insightflow-ingestion:latest

# To avoid duplicates, delete the untagged docker image first before pushing to ECR
docker rmi insightflow-ingestion

# Verify that only the tagged image is present
docker images

# Push the Docker image to ECR
docker push 864899839546.dkr.ecr.ap-southeast-2.amazonaws.com/insightflow-ingestion:latest
```