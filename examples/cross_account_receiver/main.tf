provider "aws" {
  region = "us-east-1"
}

module "default_event_bus_receiver" {
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
  # kms_cmk_arn                                 = "arn:aws:kms:us-east-1:123456789012:key/c74beb50-2e9a-4134-afb7-f7d5f26ae809"
  enable_organizational_policy_on_default_bus = true
  organization_id                             = "REDACTED"


  # Just enabling logging for visibility
  enable_logging        = true
  log_group_name        = "/aws/events/default-receiver"
  log_retention_in_days = 14
}
