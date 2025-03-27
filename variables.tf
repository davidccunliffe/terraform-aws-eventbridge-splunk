variable "name_prefix" {
  description = "Prefix for IAM roles and policies"
  type        = string
  default     = "eb"
}

variable "tags" {
  description = "Global tags for all resources"
  type        = map(string)
  default     = {}
}

variable "default_target_policy" {
  description = "Default IAM policy in JSON for target invocation if not explicitly provided"
  type        = string
  default     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}

variable "event_buses" {
  description = "List of EventBridge buses and their rules/targets"
  type = list(object({
    name = string
    tags = optional(map(string))
    rules = list(object({
      name                = string
      description         = string
      event_pattern       = string
      schedule_expression = optional(string)
      is_enabled          = bool
      tags                = optional(map(string))
      targets = list(object({
        id            = string
        arn           = string
        target_policy = optional(string)
        dlq_arn       = optional(string)
        retry_policy = optional(object({
          maximum_event_age_in_seconds = optional(number)
          maximum_retry_attempts       = optional(number)
        }))
        input_transformer = optional(object({
          input_template = string
          input_paths    = optional(map(string))
        }))
      }))
    }))
  }))
}

variable "enable_logging" {
  description = "Enable CloudWatch Logs for EventBridge"
  type        = bool
  default     = false
}

variable "log_group_name" {
  description = "Name of the CloudWatch Log Group for EventBridge logging"
  type        = string
  default     = "/aws/events/default-log-group"
}

variable "log_retention_in_days" {
  description = "Retention period for logs in CloudWatch"
  type        = number
  default     = 14
}

variable "enable_kms_cmk_encryption" {
  description = "Enable KMS key for CloudWatch Logs encryption, this will not enable the default bus for encryption that has to be manually enabled"
  type        = bool
  default     = false
}

variable "kms_cmk_arn" {
  description = "KMS CMK ARN for CloudWatch Logs encryption"
  type        = string
  default     = ""

}

variable "organization_id" {
  description = "The AWS Organization ID allowed to send events to this bus"
  type        = string
  default     = ""
}

variable "enable_organizational_policy_on_default_bus" {
  description = "Enable an AWS Organization policy on the default event bus"
  type        = bool
  default     = false
}
