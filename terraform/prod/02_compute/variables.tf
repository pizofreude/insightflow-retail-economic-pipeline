# -----------------------------------------------------
# Variables (in variables.tf)
# -----------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-2" # Or read from dev.tfvars
}

variable "env" {
  description = "Deployment environment (e.g., 'dev', 'prod')."
  type        = string
  default     = "prod" # Set to 'prod' for production
}

variable "project_name" {
  description = "Base name for the project."
  type        = string
  default     = "insightflow"
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default = {
    Project     = "InsightFlow"
    ManagedBy   = "Terraform"
    Environment = "prod" # Explicitly set to 'prod' for production
  }
}

# --- NEW Variables for Batch ---
variable "batch_container_image" {
  description = "ECR URI for the Docker container image for the Batch job."
  type        = string
  default     = "864899839546.dkr.ecr.ap-southeast-2.amazonaws.com/insightflow-ingestion:latest"   # Placeholder - REPLACE LATER with your actual ECR image URI
  # default value is "public.ecr.aws/amazonlinux/amazonlinux:latest" as placeholder needed to be updated afterwards
} 
  

variable "batch_vcpu" {
  description = "Number of vCPUs for the Batch job container."
  type        = number
  default     = 1
}

variable "batch_memory_mib" {
  description = "Memory (in MiB) for the Batch job container."
  type        = number
  default     = 2048 # 2 GiB
}
# --- End NEW Variables for Batch ---
# --- NEW Variables for Kestra EC2 ---
variable "kestra_instance_type" {
  description = "EC2 instance type for Kestra server."
  type        = string
  default     = "t3.small" # Choose based on expected load/budget
}

variable "kestra_key_name" {
  description = "Name of the EC2 Key Pair to allow SSH access (must exist in the region)."
  type        = string
  # default     = "your-key-pair-name" # Provide a default or set in tfvars if SSH needed
  # If you don't need SSH access after initial setup, you can omit this and the SSH rule in the security group.
}

variable "kestra_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access Kestra UI (port 8080). Use ['0.0.0.0/0'] for public access (less secure)."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Allows access from any IP. Restrict this in production.
}

variable "kestra_ssh_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed SSH access (port 22). Restrict to your IP."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Allows SSH from any IP. Restrict this to your IP address (e.g., ["YOUR_IP/32"]).
}
# --- End Variables for Kestra EC2 ---