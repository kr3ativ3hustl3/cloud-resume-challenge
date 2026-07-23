variable "aws_region" {
  description = "Default AWS region for resources that aren't region-locked"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain for the resume site, e.g. sunsetheard.dev — must already be registered and have a zone in Cloudflare"
  type        = string
}
