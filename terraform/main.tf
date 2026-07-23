##############################################################################
# ROOT MODULE
#
# This is the main entry point for the whole project's infrastructure
# (as opposed to terraform/bootstrap, which only ever runs once to set
# up the state backend itself).
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Points at the bucket + lock table created in terraform/bootstrap.
  # These values are NOT variables — Terraform backend blocks can't use
  # variables, so they're hardcoded here deliberately. If you rename
  # your state bucket, update this by hand.
  backend "s3" {
    bucket         = "sunificent-cloud-resume-tf-state-2026"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-resume-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ACM certificates for CloudFront must be requested in us-east-1,
# regardless of where the rest of your infrastructure lives. This
# alias exists to make that requirement explicit and impossible to get
# wrong, even though our default region already happens to be
# us-east-1 today.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Reads the API token from the CLOUDFLARE_API_TOKEN environment
# variable automatically — never hardcode a token here or commit it.
provider "cloudflare" {}

module "static_site" {
  source = "./modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    cloudflare    = cloudflare
  }

  domain_name = var.domain_name
}

module "counter_api" {
  source = "./modules/counter-api"

  providers = {
    aws = aws
  }

  allowed_origin = "https://${var.domain_name}"
}
