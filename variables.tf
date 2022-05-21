variable "cf_domain_name" {
  type = string
}

variable "cf_zone_id" {
  type = string
}

variable "enable_ipv6" {
  type    = bool
  default = true
}

variable "primary_domain" {
  type = string
}
