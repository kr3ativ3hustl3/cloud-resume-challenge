output "cloudfront_domain_name" {
  description = "The *.cloudfront.net domain — useful for testing before DNS propagates"
  value       = module.static_site.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "Needed later for cache invalidation in the CI/CD pipeline (Phase 4)"
  value       = module.static_site.cloudfront_distribution_id
}

output "s3_bucket_name" {
  description = "Needed for uploading site content and in the CI/CD pipeline (Phase 4)"
  value       = module.static_site.bucket_name
}

output "counter_api_endpoint" {
  description = "Base URL for the visitor counter API — append /count to call it"
  value       = module.counter_api.api_endpoint
}

output "counter_table_name" {
  description = "DynamoDB table name holding the visitor counter"
  value       = module.counter_api.table_name
}

output "counter_lambda_function_name" {
  description = "Lambda function name — useful for `aws logs tail`"
  value       = module.counter_api.lambda_function_name
}

output "site_url" {
  description = "The final, public URL of the site"
  value       = "https://${var.domain_name}"
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC — paste this into your workflow YAML files"
  value       = module.github_oidc.role_arn
}

