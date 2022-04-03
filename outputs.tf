output "cloudfront_oai_id" {
  value = aws_cloudfront_origin_access_identity.my_aws_cloudfront_oai.id
  sensitive = true
}