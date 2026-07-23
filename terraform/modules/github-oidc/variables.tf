variable "github_repo" {
  description = "Your GitHub repo in owner/repo format, e.g. kr3ativ3hustl3/cloud-resume-challenge — the trust policy is scoped to exactly this repo's main branch"
  type        = string
}

variable "site_bucket_arn" {
  description = "ARN of the S3 bucket holding site content"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution to allow invalidations on"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the counter Lambda function to allow code updates on"
  type        = string
}
