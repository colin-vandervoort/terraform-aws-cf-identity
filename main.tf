resource "aws_acm_certificate" "cert" {
  domain_name       = var.primary_domain
  validation_method = "DNS"
}

data "aws_route53_zone" "route53_zone" {
  name         = var.primary_domain
  private_zone = false
}

resource "aws_route53_record" "address_record" {
  for_each = toset(["A", "AAAA"])
  type     = each.key
  zone_id  = data.aws_route53_zone.route53_zone.zone_id
  name     = var.primary_domain
  records  = [aws_cloudfront_distribution.cf_dist.domain_name]
  ttl      = "300"
}

resource "aws_route53_record" "dns_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.route53_zone.zone_id
}

resource "aws_acm_certificate_validation" "cert_validate" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.dns_record : record.fqdn]
}

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

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.my_aws_cloudfront_oai.cloudfront_access_identity_path
    }

    # custom_origin_config {
    #   http_port              = 80
    #   https_port             = 443
    #   origin_protocol_policy = "https-only"
    #   origin_ssl_protocols   = ["TLSv1.2"]
    # }
  }

  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  default_root_object = var.default_root_object

  # logging_config {
  #   include_cookies = false
  #   bucket          = "mylogs.s3.amazonaws.com"
  #   prefix          = "myprefix"
  # }

  aliases = [var.primary_domain]

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

    function_association {
      event_type   = "viewer-request"
      function_arn = var.use_s3_rest_origin ? aws_cloudfront_function.dir_index_func.arn : null
    }
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
    acm_certificate_arn = aws_acm_certificate_validation.cert_validate.certificate_arn
    ssl_support_method  = "sni-only"
  }
}


