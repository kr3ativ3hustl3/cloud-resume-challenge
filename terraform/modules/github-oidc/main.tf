##############################################################################
# GITHUB OIDC MODULE
#
# Lets GitHub Actions assume an IAM role using short-lived, auto-
# expiring credentials obtained via OIDC — no long-lived AWS access
# keys are ever stored as a GitHub secret. This is the current AWS-
# and GitHub-recommended approach for CI/CD authentication.
#
# Scope, deliberately: this role can ONLY upload to the site's S3
# bucket, invalidate its CloudFront distribution, and update the
# counter Lambda's code. It CANNOT run `terraform apply`, create or
# delete infrastructure, or touch anything outside these three
# specific resources. Infrastructure changes stay a manual, deliberate
# step run by a human with the `terraform-admin` credentials — CI only
# ever deploys application code.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# GitHub's OIDC provider. Only one of these can exist per URL per AWS
# account — if you've ever set this up before (in this account, for
# any other project), this resource will fail with "already exists"
# and you should reference the existing one via a data source instead.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# Trust policy: only THIS repo, and only pushes to the `main` branch,
# may assume this role. A pull request from a fork, or a push to any
# other branch, will be rejected.
data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "cloud-resume-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  tags = {
    Project = "cloud-resume-challenge"
  }
}

# Least-privilege deploy permissions — see module header for the full
# reasoning on why this is narrower than what Terraform itself needs.
data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid    = "DeployToS3"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      var.site_bucket_arn,
      "${var.site_bucket_arn}/*",
    ]
  }

  statement {
    sid       = "InvalidateCloudFront"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [var.cloudfront_distribution_arn]
  }

  statement {
    sid    = "UpdateLambdaCode"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
    ]
    resources = [var.lambda_function_arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "cloud-resume-github-actions-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
