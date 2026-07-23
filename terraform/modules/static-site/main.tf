##############################################################################
# STATIC SITE MODULE
#
# Creates: a private S3 bucket, a CloudFront distribution in front of it
# (using Origin Access Control, the modern replacement for the older
# Origin Access Identity), an ACM certificate validated via DNS records
# in Cloudflare, and the Cloudflare DNS record that points the domain
# at CloudFront.
##############################################################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Look up the Cloudflare zone by name so we don't have to hardcode its
# ID anywhere — one less thing to keep in sync if the zone is ever
# recreated.
data "cloudflare_zone" "this" {
  name = var.domain_name
}

##############################################################################
# S3 bucket — holds the static site files. Stays fully private; the
# public internet only ever talks to CloudFront, never directly to S3.
##############################################################################

resource "aws_s3_bucket" "site" {
  bucket = "${replace(var.domain_name, ".", "-")}-site"

  tags = {
    Project = "cloud-resume-challenge"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning means a bad deploy (Phase 4) can be rolled back by
# restoring a previous object version — cheap insurance for a static
# site with very little storage.
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

##############################################################################
# CloudFront Origin Access Control (OAC) — the current AWS-recommended
# way for CloudFront to access a private S3 bucket. It replaces the
# older "Origin Access Identity" (OAI), which AWS now considers legacy.
##############################################################################

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.domain_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy: only CloudFront (specifically, THIS distribution) may
# read from the bucket. The aws:SourceArn condition is what scopes it
# to this exact distribution rather than any CloudFront distribution
# in any account.
data "aws_iam_policy_document" "site" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

##############################################################################
# ACM certificate — MUST be requested in us-east-1 for CloudFront,
# regardless of which region everything else lives in. That's why this
# resource uses the aws.us_east_1 provider alias passed in from root.
##############################################################################

resource "aws_acm_certificate" "site" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "cloud-resume-challenge"
  }
}

# ACM needs a DNS record proving we control the domain. Since DNS lives
# in Cloudflare (not Route53), we create that validation record there.
# It's kept un-proxied (DNS only / grey cloud) — proxying a validation
# record can interfere with ACM's ability to see it.
resource "cloudflare_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.cloudflare_zone.this.id
  name    = each.value.name
  type    = each.value.type
  content = each.value.value
  ttl     = 60
  proxied = false
}

# Waits for ACM to actually confirm the DNS record before moving on —
# without this, CloudFront could try to use a certificate that isn't
# validated yet and fail.
resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in cloudflare_record.cert_validation : r.hostname]
}

##############################################################################
# CloudFront distribution
##############################################################################

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  # PriceClass_100 = US, Canada, Europe edge locations only. Cheapest
  # option and plenty fast for a personal portfolio site — the wider
  # price classes mainly matter for global-scale production traffic.
  price_class = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-site-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # A static resume site has no server-rendered routes, so a missing
  # object should just serve the same index page rather than a raw
  # S3 XML error — keeps the experience clean if a bad link is followed.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = "cloud-resume-challenge"
  }
}

##############################################################################
# Cloudflare DNS record pointing the domain at CloudFront.
#
# Cloudflare supports "CNAME flattening" at the zone apex, meaning a
# CNAME record at the root domain (not just a subdomain) works
# correctly even though that's normally invalid DNS — this is a
# Cloudflare-specific feature and one reason this works cleanly even
# without Route53 ALIAS records.
##############################################################################

resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.this.id
  name    = "@"
  type    = "CNAME"
  content = aws_cloudfront_distribution.site.domain_name
  ttl     = 300
  proxied = false
}
