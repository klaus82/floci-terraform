variable "enable_s3_change_alarm" {
  description = "Enable near real-time EventBridge → SNS alarm when objects change in wp_bucket"
  type        = bool
  default     = false
}

variable "s3_change_alarm_email" {
  description = "Email address to notify on S3 object changes (required when enable_s3_change_alarm = true)"
  type        = string
  default     = null
}

variable "datadog_api_key" {
  description = "Datadog API key for sending events via EventBridge API Destination"
  type        = string
  default     = null
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site endpoint (e.g. datadoghq.com or datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_invocation_endpoint" {
  description = "Override the Datadog API endpoint (useful for testing with webhook.site)"
  type        = string
  default     = null
}
