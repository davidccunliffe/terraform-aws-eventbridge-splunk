# Terraform 1.10+ Compatible Test Using `run` Block
# Place this file in: tests/terraform_test.tftest.hcl

# RECEIVER BASIC TEST
run "receiver-basic-rule-check" {
  module {
    source = "./tests/receiver-basic"
  }

  assert {
    condition     = length(module.eventbridge_receiver.rule_names) > 0
    error_message = "Expected at least one EventBridge rule to be created"
  }

  assert {
    condition     = length(module.eventbridge_receiver.rule_arns) > 0
    error_message = "Expected rule ARNs to be present"
  }

  assert {
    condition     = length(module.eventbridge_receiver.iam_role_arns) == 0
    error_message = "Expected IAM roles to be provisioned"
  }
}

run "receiver-basic-kms-check" {
  module {
    source = "./tests/receiver-basic"
  }

  assert {
    condition     = can(module.eventbridge_receiver.kms_key_arn) && module.eventbridge_receiver.kms_key_arn != ""
    error_message = "Expected KMS Key ARN to be set when encryption is enabled"
  }
}

run "receiver-basic-log-retention-check" {
  module {
    source = "./tests/receiver-basic"
  }

  assert {
    condition     = can(module.eventbridge_receiver.log_retention_in_days) && module.eventbridge_receiver.log_retention_in_days == 14
    error_message = "Expected CloudWatch log group retention to be 14 days"
  }
}

run "receiver-basic-iam-role-check" {
  module {
    source = "./tests/receiver-basic"
  }

  assert {
    condition     = length(module.eventbridge_receiver.iam_role_arns) == 0
    error_message = "Expected IAM roles to be provisioned for Lambda or EventBridge"
  }
}

# SENDER BASIC TEST
run "sender-basic-rule-check" {
  module {
    source = "./tests/sender-basic"
  }

  assert {
    condition     = length(module.eventbridge_sender.rule_names) > 0
    error_message = "Expected at least one EventBridge rule to be created"
  }

  assert {
    condition     = length(module.eventbridge_sender.rule_arns) > 0
    error_message = "Expected rule ARNs to be present"
  }

  assert {
    condition     = length(module.eventbridge_sender.iam_role_arns) > 0
    error_message = "Expected IAM roles to be provisioned"
  }
}

run "sender-basic-kms-check" {
  module {
    source = "./tests/sender-basic"
  }

  assert {
    condition     = can(module.eventbridge_sender.kms_key_arn) && module.eventbridge_sender.kms_key_arn != ""
    error_message = "Expected KMS Key ARN to be set when encryption is enabled"
  }
}

run "sender-basic-log-retention-check" {
  module {
    source = "./tests/sender-basic"
  }

  assert {
    condition     = can(module.eventbridge_sender.log_retention_in_days) && module.eventbridge_sender.log_retention_in_days == 14
    error_message = "Expected CloudWatch log group retention to be 14 days"
  }
}

run "sender-basic-iam-role-check" {
  module {
    source = "./tests/sender-basic"
  }

  assert {
    condition     = length(module.eventbridge_sender.iam_role_arns) > 0
    error_message = "Expected IAM roles to be provisioned for Lambda or EventBridge"
  }
}