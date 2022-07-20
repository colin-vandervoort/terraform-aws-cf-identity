variable "cf_domain_name" {
  type        = string
  description = "The default domain of the CloudFront distribution."
}

variable "cf_zone_id" {
  type        = string
  description = "The zone ID of the CloudFront distribution."
}

variable "enable_ipv6" {
  type        = bool
  description = "Whether to enable IPv6. Creates AAAA records if set to true."
  default     = true
}

variable "domains" {
  type = object({
    primary   = string
    alternate = list(string)
  })
  description = "The domain(s) that should be used to access the distribution."
  validation {
    condition     = contains(var.domains.alternate, var.domains.primary) == false
    error_message = "The primary domain can not also be given as an alternate domain."
  }
}
