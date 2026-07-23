##############################################################################
# BOOTSTRAP MODULE
#
# Purpose: create the S3 bucket + DynamoDB table that the REST of this
# project's Terraform will use as its remote state backend.
#
# Why this is a separate module with LOCAL state:
# Terraform can't store its own state in a bucket that doesn't exist yet.
# This is the classic "chicken and egg" problem. The fix is to run this
# one module manually, one time, with local state (a .tfstate file on
# your own machine), and never touch it again. Every other module in
# this repo will point at the bucket/table created here.
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally NO backend block here — this module's state stays local.
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket to hold Terraform state files for all other modules.
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Prevents someone from accidentally deleting this via `terraform destroy`
  # on the wrong module — state buckets should be very hard to delete.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "cloud-resume-challenge"
    ManagedBy = "terraform-bootstrap"
  }
}

# Versioning lets you recover a previous state file if something corrupts
# the current one — cheap insurance, effectively free at this scale.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access — state files can contain sensitive data
# (resource IDs, sometimes secrets) and must never be public.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt state at rest using S3-managed keys (free, no KMS costs).
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB table for state locking. Without this, two people (or you,
# in two terminals) running `terraform apply` at once could corrupt
# your state. PAY_PER_REQUEST keeps this at $0 when idle.
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = "cloud-resume-challenge"
    ManagedBy = "terraform-bootstrap"
  }
}
