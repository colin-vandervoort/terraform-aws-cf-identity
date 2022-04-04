variable "primary_domain" {
  type = string
}

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
  default = true
}
