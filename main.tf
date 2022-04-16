resource "aws_acm_certificate" "cert" {
  domain_name       = var.primary_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  provider          = aws.east
}

data "aws_route53_zone" "route53_zone" {
  name         = var.primary_domain
  private_zone = false
  provider     = aws.east
}

resource "aws_route53_record" "address_record" {
  for_each = toset(["A", "AAAA"])
  type     = each.key
  zone_id  = data.aws_route53_zone.route53_zone.zone_id
  name     = var.primary_domain
  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_zone_id
    evaluate_target_health = false
  }
  provider = aws.east
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
  provider        = aws.east
}

resource "aws_acm_certificate_validation" "cert_validate" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.dns_record : record.fqdn]
  provider                = aws.east
}

resource "aws_cloudfront_origin_access_identity" "my_aws_cloudfront_oai" {
  comment = ""
}
