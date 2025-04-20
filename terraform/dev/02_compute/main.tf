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
    # --- NEW Locals for Glue Crawler ---
  glue_crawler_role_name    = "${local.resource_prefix}-glue-crawler-role"
  glue_crawler_policy_name  = "${local.resource_prefix}-glue-crawler-s3-policy"
  glue_crawler_name         = "${local.resource_prefix}-raw-data-crawler"
  # --- End NEW Locals for Glue Crawler ---
  # --- NEW Locals for Kestra Host ---
  kestra_ec2_role_name      = "${local.resource_prefix}-kestra-ec2-role"
  kestra_ec2_profile_name   = "${local.resource_prefix}-kestra-ec2-profile"
  kestra_ec2_sg_name        = "${local.resource_prefix}-kestra-sg"
  kestra_ec2_instance_name  = "${local.resource_prefix}-kestra-server"
  kestra_ec2_eip_name       = "${local.resource_prefix}-kestra-eip"
  # --- End NEW Locals for Kestra Host ---
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
# --- End NEW IAM Resources for Batch Service ---
# --- NEW Glue Crawler Role & Policy ---
resource "aws_iam_role" "glue_crawler_role" {
  name = local.glue_crawler_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "glue.amazonaws.com" } }
    ]
  })
  tags = local.common_tags
}

# Attach the AWS managed Glue Service Role policy
resource "aws_iam_role_policy_attachment" "glue_service_policy_attach" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy to allow Glue Crawler read access to the raw S3 bucket
resource "aws_iam_policy" "glue_s3_read_policy" {
  name        = local.glue_crawler_policy_name
  description = "Allows Glue crawler to read raw data S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          data.terraform_remote_state.storage.outputs.raw_s3_bucket_arn,
          "${data.terraform_remote_state.storage.outputs.raw_s3_bucket_arn}/raw/*" # Grant access specifically to the /raw prefix and its contents
        ]
      },
      # Allow listing the bucket itself (needed for crawler to find paths)
      {
         Action = ["s3:ListBucket"]
         Effect = "Allow"
         Resource = [data.terraform_remote_state.storage.outputs.raw_s3_bucket_arn]
         Condition = {
             StringLike = {
                 "s3:prefix": ["raw/*"] # Restrict listing to the /raw prefix
             }
         }
      }
    ]
  })
  tags = local.common_tags
}

# Attach the custom S3 read policy to the Glue Crawler role
resource "aws_iam_role_policy_attachment" "glue_s3_read_policy_attach" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = aws_iam_policy.glue_s3_read_policy.arn
}
# --- End NEW Glue Crawler Role & Policy ---

# --- NEW IAM Role & Instance Profile for Kestra EC2 ---
resource "aws_iam_role" "kestra_ec2_role" {
  name = local.kestra_ec2_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }
    ]
  })
  tags = local.common_tags
}

# Attach policies needed by Kestra tasks (AWS Plugins)
# Granting broad access for portfolio simplicity - RESTRICT IN PRODUCTION
resource "aws_iam_role_policy_attachment" "kestra_ec2_batch_access" {
  role       = aws_iam_role.kestra_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBatchFullAccess" # Allows submitting jobs, etc.
}

resource "aws_iam_role_policy_attachment" "kestra_ec2_glue_access" {
  role       = aws_iam_role.kestra_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess" # Allows starting crawlers, etc.
}

resource "aws_iam_role_policy_attachment" "kestra_ec2_s3_access" {
  role       = aws_iam_role.kestra_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Needed if Kestra tasks interact directly with S3
}

# Add other permissions as needed (e.g., Secrets Manager read)

resource "aws_iam_instance_profile" "kestra_ec2_profile" {
  name = local.kestra_ec2_profile_name
  role = aws_iam_role.kestra_ec2_role.name
  tags = local.common_tags
}
# --- End NEW Kestra EC2 IAM ---

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
    command = ["python", "main.py"]
    jobRoleArn = aws_iam_role.batch_execution_role.arn # Role for the container application
    executionRoleArn = aws_iam_role.batch_execution_role.arn # Role for ECS agent to manage container (logging, ECR pull)
    environment = [] # Pass TARGET_BUCKET during job submission overrides
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
# --- NEW Glue Crawler Resource ---
resource "aws_glue_crawler" "raw_data_crawler" {
  name          = local.glue_crawler_name
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.dbt_database.name

  s3_target {
    path = "s3://${data.terraform_remote_state.storage.outputs.raw_s3_bucket_name}/raw/" # Path to the parent raw data folder
    # exclusions = [] # Optional: exclude files/patterns if needed
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE" # Update table schema if changes detected
    delete_behavior = "LOG" # Log objects that are deleted, don't delete tables
  }

  configuration = jsonencode({
    "Version": 1.0,
    "CrawlerOutput": {
      "Partitions": { "AddOrUpdateBehavior": "InheritFromTable" } # Automatically update partitions
    },
    "Grouping": {
      "TableGroupingPolicy": "CombineCompatibleSchemas" # Try to combine schemas if similar (usually not needed with distinct dataset folders)
    }
  })

  # No schedule defined means it runs on demand
  # schedule = "cron(0 1 * * ? *)" # Example: Run daily at 1 AM UTC

  tags = local.common_tags
}
# --- End NEW Glue Crawler Resource ---
