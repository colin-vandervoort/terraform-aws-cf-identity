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

variable "origin_domain" {
  type = string
}

variable "origin_id" {
  type = string
}

variable "primary_domain" {
  type = string
}
