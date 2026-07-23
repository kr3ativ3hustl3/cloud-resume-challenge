output "bucket_name" {
  description = "Name of the S3 bucket holding site content — used for uploading files and in CI/CD"
  value       = aws_s3_bucket.site.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket — needed to scope the CI/CD IAM policy"
  value       = aws_s3_bucket.site.arn
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution — needed to scope the CI/CD IAM policy"
  value       = aws_cloudfront_distribution.site.arn
}

output "cloudfront_domain_name" {
  description = "The *.cloudfront.net domain for this distribution"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  description = "Distribution ID — needed for cache invalidation after deploys"
  value       = aws_cloudfront_distribution.site.id
}
