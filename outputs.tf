output "cert_validate_arn" {
  value     = aws_acm_certificate_validation.cert_validate.certificate_arn
  sensitive = true
}

output "cf_oai_id" {
  value = aws_cloudfront_origin_access_identity.my_aws_cloudfront_oai.id
}

output "cf_oai_path" {
  value = aws_cloudfront_origin_access_identity.my_aws_cloudfront_oai.cloudfront_access_identity_path
}