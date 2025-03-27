output "event_bus_arns" {
  description = "Map of event bus names to ARNs"
  value = {
    for name, bus in aws_cloudwatch_event_bus.buses :
    name => bus.arn
  }
}

output "rule_names" {
  description = "List of all rule names"
  value = [
    for rule in aws_cloudwatch_event_rule.rules :
    rule.name
  ]
}

output "rule_arns" {
  description = "Map of rule names to ARNs"
  value = {
    for name, rule in aws_cloudwatch_event_rule.rules :
    name => rule.arn
  }
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
  value       = var.enable_logging ? aws_cloudwatch_log_group.eventbridge_logs[0].name : null
}
