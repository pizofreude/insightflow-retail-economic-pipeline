
# -----------------------------------------------------
# Outputs (in outputs.tf)
# -----------------------------------------------------
output "batch_execution_role_arn" {
  description = "ARN of the IAM role for AWS Batch job execution."
  value       = aws_iam_role.batch_execution_role.arn
}

output "batch_compute_environment_arn" {
  description = "ARN of the Batch Compute Environment."
  value       = aws_batch_compute_environment.fargate_spot_ce.arn
}

output "batch_job_queue_arn" {
  description = "ARN of the Batch Job Queue."
  value       = aws_batch_job_queue.job_queue.arn
}

output "batch_job_definition_arn" {
  description = "ARN of the Batch Job Definition."
  value       = aws_batch_job_definition.ingestion_job_def.arn
}

output "glue_database_name" {
  description = "Name of the Glue Catalog Database created for dbt."
  value       = aws_glue_catalog_database.dbt_database.name
}