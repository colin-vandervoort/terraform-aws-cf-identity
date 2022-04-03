# resource "aws_s3_bucket" "cloudfront_logs" {
#   bucket = ""
#   tags = {
#   }
# }

resource "aws_cloudfront_origin_access_identity" "my_aws_cloudfront_oai" {
  comment = ""
}

resource "aws_cloudfront_function" "dir_index_func" {
  name    = "static_site_directory_index_function"
  runtime = "cloudfront-js-1.0"
  code    = file("${path.module}/cloudfront-funcs/directory-indexes.js")
}

resource "aws_cloudfront_distribution" "cf_dist" {
  origin {
    domain_name = var.origin_domain
    origin_id   = var.origin_id

    s3_origin_config     = local.s3_origin_config
    custom_origin_config = local.custom_origin_config
  }

  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  default_root_object = var.default_root_object

  # logging_config {
  #   include_cookies = false
  #   bucket          = "mylogs.s3.amazonaws.com"
  #   prefix          = "myprefix"
  # }

  # aliases = [var.primary_domain]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.origin_id

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

    function_association = local.dir_function_association
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# resource "aws_route53_record" "r53_rec" {
#   for_each = toset(["A", "AAAA"])
#   type     = each.key
#   zone_id  = ""
#   name     = var.primary_domain
#   records  = [aws_cloudfront_distribution.cf_dist.domain_name]
#   ttl      = "300"
# }

