# terraform/dev/02_compute/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "insightflow-terraform-state-bucket" # Bucket must exist
    key            = "env:/dev/dev/compute.tfstate"       # Unique key for this state
    region         = "ap-southeast-2"                     # Your chosen region
    dynamodb_table = "terraform-state-lock-dynamo"        # DynamoDB table must exist
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
    Environment = var.env
  })
  resource_prefix      = "${var.project_name}-${var.env}"
  batch_exec_role_name = "${local.resource_prefix}-batch-execution-role"
    # --- NEW Locals for Batch ---
  batch_service_role_name  = "${local.resource_prefix}-batch-service-role"
  batch_compute_env_name   = "${local.resource_prefix}-fargate-spot-ce"
  batch_job_queue_name     = "${local.resource_prefix}-job-queue"
  batch_job_definition_name = "${local.resource_prefix}-ingestion-job-def"
  # --- End NEW Locals for Batch ---
  # --- NEW Local for Glue DB ---
  glue_database_name        = "${var.project_name}_${var.env}" # e.g., insightflow_dev
  # --- End NEW Local for Glue DB ---
}


# -----------------------------------------------------
# IAM Resources (in iam.tf or main.tf)
# -----------------------------------------------------

# IAM Role for AWS Batch Job Execution (Container Role)
resource "aws_iam_role" "batch_execution_role" {
  name = local.batch_exec_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } },
      { Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "batch.amazonaws.com" } }
    ]
  })
  tags = local.common_tags
}

# Custom Policy allowing Batch jobs to access S3 buckets & CloudWatch Logs
resource "aws_iam_policy" "batch_s3_logs_access_policy" { 
  name        = "${local.resource_prefix}-batch-s3-logs-access-policy"
  description = "Allows Batch jobs to read/write S3 and write CloudWatch Logs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
        Effect   = "Allow"
        Resource = [
          data.terraform_remote_state.storage.outputs.raw_s3_bucket_arn,
          "${data.terraform_remote_state.storage.outputs.raw_s3_bucket_arn}/*",
          data.terraform_remote_state.storage.outputs.processed_s3_bucket_arn,
          "${data.terraform_remote_state.storage.outputs.processed_s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
  tags = local.common_tags
}

# Attach Custom Policy to Batch Execution Role
resource "aws_iam_role_policy_attachment" "batch_s3_logs_policy_attach" {
  role       = aws_iam_role.batch_execution_role.name
  policy_arn = aws_iam_policy.batch_s3_logs_access_policy.arn
}

# Attach AWS Managed Policy for ECS Task Execution (needed for Batch Fargate)
resource "aws_iam_role_policy_attachment" "batch_ecs_task_exec_policy_attach" {
  role       = aws_iam_role.batch_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# --- NEW IAM Resources for Batch Service ---
# IAM Role for AWS Batch Service
resource "aws_iam_role" "batch_service_role" {
  name = local.batch_service_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "batch.amazonaws.com" } }
    ]
  })
  tags = local.common_tags
}

# Attach AWS Managed Policy for Batch Service Role
resource "aws_iam_role_policy_attachment" "batch_service_policy_attach" {
  role       = aws_iam_role.batch_service_role.name
  # This managed policy grants Batch permissions to manage resources like ECS, EC2 (if used), etc.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}
# --- End NEW IAM Resources ---

# -----------------------------------------------------
# AWS Batch Resources (NEW - in batch.tf or main.tf)
# -----------------------------------------------------

# AWS Batch Compute Environment (Fargate Spot)
resource "aws_batch_compute_environment" "fargate_spot_ce" {
  compute_environment_name = local.batch_compute_env_name
  type                     = "MANAGED"
  state                    = "ENABLED"
  service_role             = aws_iam_role.batch_service_role.arn # Use the service role created above

  compute_resources {
    type                     = "FARGATE_SPOT" # Use Fargate Spot for cost savings
    max_vcpus                = 16             # Adjust max vCPUs as needed
    subnets                  = data.aws_subnets.default.ids # Use default VPC subnets
    security_group_ids       = [data.aws_security_group.default.id] # Use default security group
    # Assign public IP is needed if your subnets are public and container needs internet access
    # assign_public_ip = "ENABLED"
  }

  tags = local.common_tags
}

# AWS Batch Job Queue
resource "aws_batch_job_queue" "job_queue" {
  name     = local.batch_job_queue_name
  state    = "ENABLED"
  priority = 1 # Lower number is lower priority

  # Use compute_environment_order instead of compute_environments
  compute_environment_order {
    order = 1 # Order for the compute environment
    compute_environment = aws_batch_compute_environment.fargate_spot_ce.arn # Map queue to the compute environment
  }

  tags = local.common_tags
}

# AWS Batch Job Definition
resource "aws_batch_job_definition" "ingestion_job_def" {
  name = local.batch_job_definition_name
  type = "container"

  platform_capabilities = ["FARGATE"] # Required for Fargate compute environments

  container_properties = jsonencode({
    image = var.batch_container_image # Use variable for image URI (REPLACE LATER)
    command = ["echo", "Replace with actual command, e.g., python script.py"] # Placeholder command
    jobRoleArn = aws_iam_role.batch_execution_role.arn # Role for the container application
    executionRoleArn = aws_iam_role.batch_execution_role.arn # Role for ECS agent to manage container (logging, ECR pull)
    environment = [ # Example environment variables - add secrets/config here later
      { name = "DATA_SOURCE_URL_1", value = "http://example.com/data1" },
      { name = "TARGET_BUCKET", value = data.terraform_remote_state.storage.outputs.raw_s3_bucket_name }
    ]
    networkConfiguration = {
      assignPublicIp = "ENABLED" # Enable if container needs outbound internet access (e.g., to download data)
    }
    logConfiguration = { # Optional: Configure CloudWatch Logs driver
        logDriver = "awslogs"
        options = {
           "awslogs-group"         = "/aws/batch/${local.batch_job_definition_name}" # Log group name
           "awslogs-region"        = var.aws_region
           "awslogs-stream-prefix" = "batch"
        }
    }
    # Define resource requirements for Fargate
    resourceRequirements = [
      { type = "VCPU",   value = tostring(var.batch_vcpu) },        # Value must be string
      { type = "MEMORY", value = tostring(var.batch_memory_mib) }   # Value must be string
    ]

  })

  # Optional: Retry strategy, timeout, tags
  retry_strategy {
    attempts = 1
  }

  tags = local.common_tags
}
# --- End NEW Batch Resources ---

# -----------------------------------------------------
# AWS Glue Resources (NEW - in glue.tf or main.tf)
# -----------------------------------------------------

resource "aws_glue_catalog_database" "dbt_database" {
  name = local.glue_database_name # e.g., insightflow_dev
  # description = "Glue database for ${var.env} environment managed by dbt." # Optional description
  # location_uri = "s3://${data.terraform_remote_state.storage.outputs.processed_s3_bucket_name}/${local.glue_database_name}/" # Optional: Define default location

  tags = local.common_tags
}
# --- End NEW Glue Resources ---
