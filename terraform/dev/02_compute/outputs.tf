
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

output "glue_crawler_name" {
  description = "Name of the Glue Crawler created."
  value       = aws_glue_crawler.raw_data_crawler.name
}

output "kestra_ui_url" {
  description = "URL to access the Kestra UI. Use http://<IP_ADDRESS>:8080"
  value       = "http://${aws_eip.kestra_eip.public_ip}:8080" # Use Elastic IP if created
  # value       = "http://${aws_instance.kestra_server.public_ip}:8080" # Use instance public IP if no EIP
}

output "kestra_server_ssh_command" {
  description = "Command to SSH into the Kestra server (replace key path)."
  value       = "ssh -i /path/to/${var.kestra_key_name}.pem ec2-user@${aws_eip.kestra_eip.public_ip}" # Use Elastic IP if created
  # value       = "ssh -i /path/to/${var.kestra_key_name}.pem ec2-user@${aws_instance.kestra_server.public_ip}" # Use instance public IP if no EIP
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for AWS Batch jobs."
  value       = aws_cloudwatch_log_group.batch_job_logs.name
}