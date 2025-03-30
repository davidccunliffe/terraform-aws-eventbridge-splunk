output "event_buses" {
  description = "List of all event bus objects"
  value = [
    for bus in aws_cloudwatch_event_bus.buses :
    {
      name = bus.name
      arn  = bus.arn
    }
  ]
}

output "event_bus_arns" {
  description = "Map of event bus names to ARNs"
  value = {
    for name, bus in aws_cloudwatch_event_bus.buses :
    name => bus.arn
  }
}

output "rule_names" {
  description = "List of all rule names"

  value = concat(
    [for rule in aws_cloudwatch_event_rule.rules : rule.name],
    [
      for rule in aws_cloudwatch_event_rule.default_logging_rule :
      rule.name
    ]
  )
}

output "rule_arns" {
  description = "Map of rule names to ARNs"

  value = merge(
    {
      for name, rule in aws_cloudwatch_event_rule.rules :
      name => rule.arn
    },
    {
      for rule in aws_cloudwatch_event_rule.default_logging_rule :
      rule.name => rule.arn
    }
  )
}


output "iam_role_arns" {
  description = "Map of role identifiers to IAM role ARNs"
  value = {
    for k, v in aws_iam_role.invoke_roles :
    k => v.arn
  }
}

output "log_group_name" {
  description = "CloudWatch log group name if logging is enabled"
  value       = var.enable_logging ? aws_cloudwatch_log_group.eventbridge_logs[0].name : var.log_group_name
}

output "log_retention_in_days" {
  description = "Retention period for logs in CloudWatch"
  value       = var.enable_logging ? aws_cloudwatch_log_group.eventbridge_logs[0].retention_in_days : var.log_retention_in_days
}

output "kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption"
  value       = var.enable_kms_cmk_encryption ? aws_kms_key.eventbridge_cmk_key[0].arn : var.kms_cmk_arn
}

output "cross_account_event_target_arns" {
  description = "List of cross-account event target ARNs"
  value = concat(
    [for target in aws_cloudwatch_event_target.targets : target.arn],
    [for target in aws_cloudwatch_event_target.default_log_target : target.arn]
  )
}
