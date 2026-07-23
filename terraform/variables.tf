variable "aws_region" {
  description = "Default AWS region for resources that aren't region-locked"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain for the resume site, e.g. sunsetheard.dev — must already be registered and have a zone in Cloudflare"
  type        = string
}

variable "github_repo" {
  description = "Your GitHub repo in owner/repo format, e.g. kr3ativ3hustl3/cloud-resume-challenge"
  type        = string
}
