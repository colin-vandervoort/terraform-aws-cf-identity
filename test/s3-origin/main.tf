terraform {
  required_version = ">= 1.1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8.0"
    }
  }
}

variable "aws_region" {
  type = string
}

variable "bucket" {
  type = string
}

variable "primary_domain" {
  type = string
}

locals {
  s3_origin_id = "test_s3_origin"
  enable_ipv6  = true
}

provider "aws" {
  region = var.aws_region
}

// Module under test
module "terraform_aws_cloudfront_support" {
  source         = "../.."
  primary_domain = var.primary_domain
  enable_ipv6    = local.enable_ipv6
  cf_domain_name = aws_cloudfront_distribution.cf_dist.domain_name
  cf_zone_id     = aws_cloudfront_distribution.cf_dist.hosted_zone_id
}

// S3 site bucket
resource "aws_s3_bucket" "test_static_files" {
  bucket = var.bucket
}

resource "aws_s3_bucket_policy" "blog_static_files_policy" {
  bucket = aws_s3_bucket.test_static_files.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${module.terraform_aws_cloudfront_support.cf_oai_id}"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.test_static_files.arn,
      "${aws_s3_bucket.test_static_files.arn}/*",
    ]
  }
}

resource "aws_cloudfront_distribution" "cf_dist" {
  origin {
    domain_name = aws_s3_bucket.test_static_files.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = module.terraform_aws_cloudfront_support.cf_oai_path
    }
  }

  enabled         = true
  is_ipv6_enabled = local.enable_ipv6

  aliases = [var.primary_domain]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "test"
  }

  viewer_certificate {
    acm_certificate_arn = module.terraform_aws_cloudfront_support.cert_validate_arn
    ssl_support_method  = "sni-only"
  }
}

output "s3_static_files_bucket_id" {
  value = aws_s3_bucket.test_static_files.id
}