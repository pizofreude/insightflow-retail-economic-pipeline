# -----------------------------------------------------
# Outputs (in outputs.tf)
# -----------------------------------------------------
output "raw_s3_bucket_name" {
  description = "Name of the S3 bucket for raw data."
  value       = aws_s3_bucket.raw_data.bucket
}

output "raw_s3_bucket_arn" {
  description = "ARN of the S3 bucket for raw data."
  value       = aws_s3_bucket.raw_data.arn
}

output "processed_s3_bucket_name" {
  description = "Name of the S3 bucket for processed data."
  value       = aws_s3_bucket.processed_data.bucket
}

output "processed_s3_bucket_arn" {
  description = "ARN of the S3 bucket for processed data."
  value       = aws_s3_bucket.processed_data.arn
}