# Add a default rule to log all activity to CloudWatch Logs if logging is enabled and no rules exist
locals {
  eventbridge_targets = {
    for item in flatten([
      for bus in var.event_buses : [
        for rule in bus.rules : [
          for target in rule.targets : {
            key      = "${bus.name}:${rule.name}:${target.id}"
            bus_name = bus.name
            rule     = rule
            target   = target
            policy   = try(target.target_policy, var.default_target_policy)
          }
        ]
      ]
    ]) : item.key => item
  }

  has_rules = length(flatten([for bus in var.event_buses : bus.rules])) > 0
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Organization Event Sink Policy
resource "aws_cloudwatch_event_bus_policy" "org_sender_policy" {
  count = var.enable_organizational_policy_on_default_bus ? 1 : 0
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowOrgSendEvents",
        Effect    = "Allow",
        Principal = "*",
        Action    = "events:PutEvents",
        Resource  = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default",
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      }
    ]
  })
}

# Can't manage the default bus directly have to use data source
# Can't directly add kms key or dlq to the default bus either
# https://github.com/hashicorp/terraform-provider-aws/issues/41585
data "aws_cloudwatch_event_bus" "default" {
  for_each = {
    for bus in var.event_buses : bus.name => bus
    if bus.name == "default"
  }

  name = "default"
}

resource "aws_cloudwatch_event_bus" "buses" {
  for_each = {
    for bus in var.event_buses : bus.name => bus
    if bus.name != "default"
  }

  name = each.key
  tags = merge(var.tags, try(each.value.tags, {}))
}

resource "aws_cloudwatch_event_rule" "rules" {
  for_each = {
    for item in flatten([
      for bus in var.event_buses : [
        for rule in bus.rules : {
          key      = "${bus.name}:${rule.name}"
          bus_name = bus.name
          rule     = rule
        }
      ]
    ]) : item.key => item
  }

  name                = each.value.rule.name
  description         = each.value.rule.description
  event_bus_name      = each.value.bus_name == "default" ? data.aws_cloudwatch_event_bus.default["default"].name : aws_cloudwatch_event_bus.buses[each.value.bus_name].name
  event_pattern       = each.value.rule.event_pattern
  schedule_expression = try(each.value.rule.schedule_expression, null)
  state               = each.value.rule.is_enabled ? "ENABLED" : "DISABLED"
  tags                = merge(var.tags, try(each.value.rule.tags, {}))
}

# TODO Need to add variable to accept the acocunts to allow to send events to the default bus
resource "aws_cloudwatch_event_rule" "default_logging_rule" {
  count = var.enable_logging && !local.has_rules ? 1 : 0

  name           = "eventbridge-capture-all"
  description    = "Capture all events for logging"
  event_bus_name = "default"

  # manually added to test the cross account event
  event_pattern = jsonencode({
    "source" : [{ "prefix" : "" }]
  })

  # This needs to be updated to allow the accounts to send events to the default bus
  # event_pattern  = jsonencode({ "account" : [data.aws_caller_identity.current.account_id] })
  state = "ENABLED"
  tags  = var.tags
}

resource "aws_iam_role" "invoke_roles" {
  for_each = local.eventbridge_targets

  name = "${var.name_prefix}-${each.value.rule.name}-${each.value.target.id}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "invoke_policies" {
  for_each = local.eventbridge_targets

  name   = replace(each.key, ":", "-")
  role   = aws_iam_role.invoke_roles[each.key].id
  policy = each.value.policy
}

resource "aws_cloudwatch_event_target" "targets" {
  for_each = local.eventbridge_targets

  rule           = aws_cloudwatch_event_rule.rules["${each.value.bus_name}:${each.value.rule.name}"].name
  target_id      = each.value.target.id
  arn            = each.value.target.arn
  role_arn       = aws_iam_role.invoke_roles[each.key].arn
  event_bus_name = each.value.bus_name == "default" ? data.aws_cloudwatch_event_bus.default["default"].name : aws_cloudwatch_event_bus.buses[each.value.bus_name].name


  dynamic "dead_letter_config" {
    for_each = each.value.target.dlq_arn != null ? [1] : []
    content {
      arn = each.value.target.dlq_arn
    }
  }

  dynamic "retry_policy" {
    for_each = each.value.target.retry_policy != null ? [1] : []
    content {
      maximum_event_age_in_seconds = try(each.value.target.retry_policy.maximum_event_age_in_seconds, null)
      maximum_retry_attempts       = try(each.value.target.retry_policy.maximum_retry_attempts, null)
    }
  }

  dynamic "input_transformer" {
    for_each = each.value.target.input_transformer != null ? [1] : []
    content {
      input_template = each.value.target.input_transformer.input_template
      input_paths    = try(each.value.target.input_transformer.input_paths, null)
    }
  }
}

resource "aws_cloudwatch_log_group" "eventbridge_logs" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/lambda/eventbridge-default-logger"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.enable_kms_cmk_encryption ? (var.kms_cmk_arn == "" ? aws_kms_key.eventbridge_cmk_key[0].arn : var.kms_cmk_arn) : null

  tags = var.tags
}

resource "aws_lambda_function" "log_receiver" {
  count            = var.enable_logging && !local.has_rules ? 1 : 0
  function_name    = "eventbridge-default-logger"
  role             = aws_iam_role.lambda_logger[0].arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = "${path.module}/log_receiver.zip"
  source_code_hash = filebase64sha256("${path.module}/log_receiver.zip")
  kms_key_arn      = var.enable_kms_cmk_encryption ? (var.kms_cmk_arn == "" ? aws_kms_key.eventbridge_cmk_key[0].arn : var.kms_cmk_arn) : null

  tags = var.tags
}

resource "aws_iam_role" "lambda_logger" {
  count = var.enable_logging && !local.has_rules ? 1 : 0
  name  = "eventbridge-logger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logger_policy" {
  count      = var.enable_logging && !local.has_rules ? 1 : 0
  role       = aws_iam_role.lambda_logger[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_logging && !local.has_rules ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  function_name = aws_lambda_function.log_receiver[0].function_name
  source_arn    = aws_cloudwatch_event_rule.default_logging_rule[0].arn
}

resource "aws_cloudwatch_event_target" "default_log_target" {
  count          = var.enable_logging && !local.has_rules ? 1 : 0
  rule           = aws_cloudwatch_event_rule.default_logging_rule[0].name
  target_id      = aws_lambda_function.log_receiver[0].function_name
  arn            = aws_lambda_function.log_receiver[0].arn
  event_bus_name = "default"

}

resource "aws_kms_key" "eventbridge_cmk_key" {
  count = var.enable_kms_cmk_encryption ? (var.kms_cmk_arn == "" ? 1 : 0) : 0

  description             = "KMS CMK for EventBridge with cross-account access"
  enable_key_rotation     = true
  rotation_period_in_days = 365

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "eventbridge-key-policy",
    Statement = [
      {
        Sid    = "AllowRootAccountFullAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchService",
        Effect = "Allow",
        Principal = {
          Service = "logs.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowEventBridgeService",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaService",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid       = "AllowOrgAccountsToUseKey",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "eventbridge-lambda-key"
    Environment = "shared"
  }
}

resource "aws_kms_alias" "eventbridge_key_alias" {
  count         = var.enable_kms_cmk_encryption ? (var.kms_cmk_arn == "" ? 1 : 0) : 0
  name          = "alias/eventbridge-hub"
  target_key_id = aws_kms_key.eventbridge_cmk_key[0].key_id
}
