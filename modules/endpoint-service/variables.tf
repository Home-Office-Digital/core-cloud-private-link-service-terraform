###################
# Perimeter / Common Variables
###################

variable "account_id" {
  description = "AWS account ID for the perimeter account (used for tagging/metadata if needed)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the NLB and endpoint service will be created."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the NLB nodes."
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}

###################
# PrivateLink Services (per-service config)
###################

variable "pl_services" {
  description = "Map of PrivateLink services to create."
  type = map(object({
    name = string

    service_target_ips = list(string)
    listener_port      = optional(number, 443)
    protocol           = optional(string, "TCP")

    acceptance_required = optional(bool, true)
    allowed_principals  = optional(set(string), [])
  }))

  validation {
    condition     = alltrue([for _, svc in var.pl_services : length(svc.service_target_ips) == 3])
    error_message = "Each pl_service must provide exactly 3 service_target_ips."
  }
}

variable "supported_regions" {
  description = "Regions supported by the VPC Endpoint Service (PrivateLink). Null/empty means default (same region only)."
  type        = list(string)
  default     = null
}

############################
# S3 Variables
############################
variable "name_prefix" {
  description = "Prefix used for shared resources like the NLB access logs bucket"
  type        = string
  default     = "cc-private-link-services"
}

variable "nlb_access_logs_retention_days" {
  description = "How long to retain NLB access logs in S3"
  type        = number
  default     = 30
}

variable "existing_nlb_access_logs_bucket_name" {
  description = "Existing shared S3 bucket name for NLB access logs. When set, this module will not create or manage the log bucket resources."
  type        = string
  default     = null
}