# This file is used to configure the backend for storing Terraform state files.
# It specifies the S3 bucket and DynamoDB table where Terraform state files will be stored.
# The bucket must exist before running Terraform commands


# terraform/dev/02_compute/backend.tf (and similarly in 01_storage)
terraform {
  backend "s3" {
    bucket         = "insightflow-terraform-state-bucket" # Bucket must exist
    key            = "dev/compute.tfstate"                # Unique key for this state
    region         = var.aws_region                       # Your chosen region
    dynamodb_table = "terraform-state-lock-dynamo"        # DynamoDB table must exist
    encrypt        = true
  }
}