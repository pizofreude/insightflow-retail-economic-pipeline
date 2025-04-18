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
