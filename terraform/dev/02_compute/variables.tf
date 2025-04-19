# -----------------------------------------------------
# Variables (in variables.tf)
# -----------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-2" # Or read from dev.tfvars
}

variable "env" {
  description = "Deployment environment (e.g., 'dev')."
  type        = string
  # Default value can be set here or in dev.tfvars
  # default = "dev"
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
    Project   = "InsightFlow"
    ManagedBy = "Terraform"
  }
}

# --- NEW Variables for Batch ---
variable "batch_container_image" {
  description = "ECR URI for the Docker container image for the Batch job."
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:latest" # Placeholder - REPLACE LATER with your actual ECR image URI
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