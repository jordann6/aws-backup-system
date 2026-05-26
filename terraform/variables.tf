variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (dev / prod)."
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address that receives daily backup confirmation."
  type        = string
}

variable "sendgrid_api_key" {
  description = "SendGrid API key for outbound email. Leave empty to disable email notifications."
  type        = string
  sensitive   = true
  default     = ""
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent object versions before deletion (equivalent to soft-delete window)."
  type        = number
  default     = 90
}

variable "ia_tier_after_days" {
  description = "Days since last modification before moving to Standard-IA."
  type        = number
  default     = 30
}

variable "glacier_tier_after_days" {
  description = "Days since last modification before moving to Glacier Flexible Retrieval."
  type        = number
  default     = 90
}

variable "delete_after_days" {
  description = "Days since last modification before permanent deletion."
  type        = number
  default     = 365
}
