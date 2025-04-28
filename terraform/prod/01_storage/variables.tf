# -----------------------------------------------------
# Variables (in variables.tf)
# -----------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-2" # Ensure this matches the production region
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
    Project   = "InsightFlow"
    ManagedBy = "Terraform"
    Environment = "prod" # Explicitly set to 'prod' for production
  }
}