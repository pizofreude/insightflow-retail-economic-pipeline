# -----------------------------------------------------
# Data Source: Read Storage Layer Outputs (in data.tf)
# -----------------------------------------------------
data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = "insightflow-terraform-state-bucket" # REPLACE with your state bucket
    key    = "env:/dev/dev/storage.tfstate"       # Key for the storage layer state
    region = "ap-southeast-2"                     # Must matched backend region
  }
}

# Data source to get current AWS account ID (used in policy ARN)
data "aws_caller_identity" "current" {}

# --- NEW Data Sources for Networking ---
# Get Default VPC
data "aws_vpc" "default" {
  default = true
}

# Get Subnets in Default VPC (Fargate needs these)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get Default Security Group (or create a specific one)
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}
# --- End NEW Data Sources for Networking ---
