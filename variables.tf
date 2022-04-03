# variable "primary_domain" {
#   type = string
# }

variable "origin_domain" {
  type = string
}

variable "origin_id" {
  type = string
}

variable "enable_ipv6" {
  type    = bool
  default = true
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "default_root_object" {
  type    = string
  default = "index.html"
}

variable "use_s3_rest_origin" {
  type    = bool
  default = false
}

locals {
  dir_function_association = var.use_s3_rest_origin ? {
    event_type   = "viewer-request"
    function_arn = aws_cloudfront_function.dir_index_func.arn
  } : null

  s3_origin_config = var.use_s3_rest_origin ? {
    origin_access_identity = aws_cloudfront_origin_access_identity.my_aws_cloudfront_oai.cloudfront_access_identity_path
  } : null

  custom_origin_config = var.use_s3_rest_origin ? null : {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols   = "TLSv1.2"
  }
}
