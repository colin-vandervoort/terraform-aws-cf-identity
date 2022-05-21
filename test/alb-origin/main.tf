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

variable "primary_domain" {
  type = string
}

variable "origin_domain" {
  type = string
}

variable "html_text" {
  type = string
}

locals {
  instance_name          = "cloudfront-to-ec2-test"
  instance_type          = "t2.micro"
  origin_id              = "ec2-test-instance"
  origin_http_port       = 80
  origin_https_port      = 443
  origin_protocol_policy = "https-only"
  origin_ssl_protocols   = ["TLSv1.2"]
  enable_ipv6            = true
}

provider "aws" {
  region = var.aws_region
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    instance_text = var.html_text
    instance_port = local.origin_https_port
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
}

// Module under test
module "terraform_aws_cloudfront_support" {
  source         = "../.."
  primary_domain = var.primary_domain
  enable_ipv6    = local.enable_ipv6
  cf_domain_name = aws_cloudfront_distribution.cf_dist.domain_name
  cf_zone_id     = aws_cloudfront_distribution.cf_dist.hosted_zone_id
}


resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  user_data              = data.template_file.user_data.rendered
  vpc_security_group_ids = [aws_security_group.example.id]

  tags = {
    Name = local.instance_name
  }
}

resource "aws_cloudfront_distribution" "cf_dist" {
  origin {
    domain_name = var.origin_domain
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = local.origin_http_port
      https_port             = local.origin_https_port
      origin_protocol_policy = local.origin_protocol_policy
      origin_ssl_protocols   = local.origin_ssl_protocols
    }
  }

  enabled         = true
  is_ipv6_enabled = local.enable_ipv6

  aliases = [var.primary_domain]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

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
