terraform {
  required_version = ">= 1.10"
}


provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

module "eventbridge_sender" {
  source = "../../"

  name_prefix = "sender"

  enable_kms_cmk_encryption = true
  enable_logging            = true
  log_group_name            = "/aws/events/test-eventbridge-log-group"
  log_retention_in_days     = 14
  organization_id           = "o-1234567890"

  tags = {
    Environment = "dev"
    Team        = "platform"
    Purpose     = "send-to-org-bus"
  }

  event_buses = [
    {
      name = "default"
      rules = [
        {
          name          = "send-to-org-default-bus"
          description   = "Sends all events to another account's default event bus"
          is_enabled    = true
          event_pattern = jsonencode({ account = [data.aws_caller_identity.current.account_id] })

          targets = [
            {
              id  = "receiver-default-bus"
              arn = "arn:aws:events:us-east-1:123456789012:event-bus/default"

              target_policy = jsonencode({
                Version = "2012-10-17",
                Statement = [
                  {
                    Effect   = "Allow",
                    Action   = "events:PutEvents",
                    Resource = "arn:aws:events:us-east-1:123456789012:event-bus/default"
                  }
                ]
              })
            }
          ]
        }
      ]
    }
  ]
}

output "module" {
  value = module.eventbridge_sender
}

output "rule_names" {
  value = module.eventbridge_sender.rule_names
}

output "rule_arns" {
  value = module.eventbridge_sender.rule_arns
}

output "iam_role_arns" {
  value = module.eventbridge_sender.iam_role_arns
}

output "kms_key_arn" {
  value = module.eventbridge_sender.kms_key_arn
}

output "log_retention_in_days" {
  value = module.eventbridge_sender.log_retention_in_days
}