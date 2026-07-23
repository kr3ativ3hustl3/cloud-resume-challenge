output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state — you'll need this for every other module's backend config"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table — you'll need this for every other module's backend config"
  value       = aws_dynamodb_table.tf_lock.name
}

output "aws_region" {
  description = "Region the backend resources were created in"
  value       = var.aws_region
}
