# terraform/prod/01_storage/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "insightflow-terraform-state-bucket" # Same bucket for state
    key            = "env:/prod/prod/storage.tfstate"     # Unique key for production state
    region         = "ap-southeast-2"                     # Your chosen region
    dynamodb_table = "terraform-state-lock-dynamo"        # Same DynamoDB table for locking
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------
# Locals (in main.tf or locals.tf)
# -----------------------------------------------------
locals {
  common_tags = merge(var.tags, {
    Environment = "prod" # Explicitly set to production
  })
  resource_prefix          = "${var.project_name}-prod"
  s3_raw_bucket_name       = "${local.resource_prefix}-raw-data"
  s3_processed_bucket_name = "${local.resource_prefix}-processed-data"
}

# -----------------------------------------------------
# S3 Resources (in s3.tf or main.tf)
# -----------------------------------------------------

# Raw Data Bucket
resource "aws_s3_bucket" "raw_data" {
  bucket = local.s3_raw_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "raw_data_versioning" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "raw_data_public_access" {
  bucket                  = aws_s3_bucket.raw_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data_sse" {
  bucket = aws_s3_bucket.raw_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Processed Data Bucket
resource "aws_s3_bucket" "processed_data" {
  bucket = local.s3_processed_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "processed_data_versioning" {
  bucket = aws_s3_bucket.processed_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "processed_data_public_access" {
  bucket                  = aws_s3_bucket.processed_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_data_sse" {
  bucket = aws_s3_bucket.processed_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}