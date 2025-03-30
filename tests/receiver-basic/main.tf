terraform {
  required_version = ">= 1.10"
}


provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "current" {}

module "eventbridge_receiver" {
  source = "../.."

  name_prefix = "receiver"
  tags = {
    environment = "shared"
    purpose     = "org-wide event intake"
  }

  # No need to define custom event_buses because we're using the default event bus.
  # The module also builds a default bus rule that will deploy a lambda to cloudwatch logs
  # If no rules are passed in the event_buses variable
  event_buses = []

  enable_kms_cmk_encryption = true
  enable_organizational_policy_on_default_bus = true
  organization_id                             = "${data.aws_organizations_organization.current.id}"


  # Just enabling logging for visibility
  enable_logging        = true
  log_group_name        = "/aws/events/default-receiver"
  log_retention_in_days = 14
}


output "rule_names" {
  value = module.eventbridge_receiver.rule_names
}

output "rule_arns" {
  value = module.eventbridge_receiver.rule_arns
}

output "iam_role_arns" {
  value = module.eventbridge_receiver.iam_role_arns
}

output "kms_key_arn" {
  value = module.eventbridge_receiver.kms_key_arn
}

output "log_retention_in_days" {
  value = module.eventbridge_receiver.log_retention_in_days
}
