locals {
  alias_domain_set = toset(concat([var.domains.primary], var.domains.alternate))
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domains.primary
  subject_alternative_names = var.domains.alternate
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  provider = aws.east
}

data "aws_route53_zone" "route53_zone" {
  name         = var.domains.primary
  private_zone = false
  provider     = aws.east
}

resource "aws_route53_record" "a" {
  for_each = local.alias_domain_set
  type     = "A"
  zone_id  = data.aws_route53_zone.route53_zone.zone_id
  name     = each.key
  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_zone_id
    evaluate_target_health = false
  }
  provider = aws.east
}

resource "aws_route53_record" "aaaa" {
  for_each = var.enable_ipv6 ? local.alias_domain_set : toset([])
  type     = "AAAA"
  zone_id  = data.aws_route53_zone.route53_zone.zone_id
  name     = each.key
  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_zone_id
    evaluate_target_health = false
  }
  provider = aws.east
}

resource "aws_route53_record" "cert_validation_dns" {
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
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_dns : record.fqdn]
  provider                = aws.east
}

resource "aws_cloudfront_origin_access_identity" "my_aws_cloudfront_oai" {
  comment = ""
}
