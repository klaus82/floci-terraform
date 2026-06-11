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
