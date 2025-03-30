The `terraform-aws-eventbridge-splunk` repository provides a Terraform module designed to integrate AWS EventBridge with Splunk. This module automates the setup of AWS resources necessary to forward events from EventBridge to a Splunk Cloudwatch log group for centralized logging and analysis.

## Features

- **AWS EventBridge Integration**: Sets up EventBridge rules to capture specific events. By default this will capture all events in the hub account.
- **AWS Lambda Function**: Deploys a Lambda function that processes incoming events and forwards them to a default cloudwatch log group.
- **IAM Roles and Policies**: Creates the necessary IAM roles and policies to grant permissions for EventBridge and Lambda operations.
- **KMS Customer Managed Keys**: Creates the necessary centralized key for the usage of EventBridge opearations. This will not set the default hub encryption settgins only managed.

## Usage

### Cross-Account Receiver

In the `examples` directory, you’ll find a basic example demonstrating how to configure this module as a **central event receiver**. This setup creates an EventBridge rule, a corresponding AWS Lambda function, and a CloudWatch Log Group to receive and process incoming events from other AWS accounts.

### Cross-Account Sender

Also located in the `examples` directory is a sample configuration for a **cross-account sender**. This example shows how to create an EventBridge rule on the default event bus that filters specific event types and forwards them to the central receiver in another AWS account.

---

Let me know if you want these expanded into example blocks with code references!

# Testing the eventbus
```bash
#!/bin/bash

counter=1

while true; do
  aws events put-events --entries '[
    {
      "Source": "custom.test.access-analyzer",
      "DetailType": "Access Analyzer Finding",
      "Detail": "{\"analyzerArn\": \"arn:aws:access-analyzer:us-east-1:111122223333:analyzer/org-analyzer\", \"status\": \"ACTIVE\", \"resourceType\": \"AWS::S3::Bucket\", \"resource\": \"arn:aws:s3:::my-public-bucket\"}",
      "EventBusName": "default"
    }
  ]' > /dev/null 2>&1

  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Event sent #$counter"

  ((counter++))
  sleep 1
done
```

---

## Resources Created

When deployed with default settings, this module provisions the following AWS resources:

1. **AWS EventBridge Rule**: Captures events based on defined patterns. Default is capture all!
2. **AWS Lambda Function**: Processes and forwards events to Cloudwatch Log Group.
3. **IAM Role for Lambda**: Grants the Lambda function permissions to be invoked by EventBridge and to send data to Splunk.
4. **IAM Policy for Lambda**: Defines the specific permissions required by the Lambda function. Such as Cloudwatch log groups publishing.

## Module Inputs and Outputs

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_bus.buses](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_bus_policy.org_sender_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus_policy) | resource |
| [aws_cloudwatch_event_rule.default_logging_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.default_log_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.eventbridge_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.invoke_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_logger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.invoke_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_logger_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.eventbridge_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.eventbridge_cmk_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.log_receiver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudwatch_event_bus.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudwatch_event_bus) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_target_policy"></a> [default\_target\_policy](#input\_default\_target\_policy) | Default IAM policy in JSON for target invocation if not explicitly provided | `string` | `"{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Effect\": \"Allow\",\n      \"Action\": \"*\",\n      \"Resource\": \"*\"\n    }\n  ]\n}\n"` | no |
| <a name="input_enable_kms_cmk_encryption"></a> [enable\_kms\_cmk\_encryption](#input\_enable\_kms\_cmk\_encryption) | Enable KMS key for CloudWatch Logs encryption, this will not enable the default bus for encryption that has to be manually enabled | `bool` | `false` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enable CloudWatch Logs for EventBridge | `bool` | `false` | no |
| <a name="input_enable_organizational_policy_on_default_bus"></a> [enable\_organizational\_policy\_on\_default\_bus](#input\_enable\_organizational\_policy\_on\_default\_bus) | Enable an AWS Organization policy on the default event bus | `bool` | `false` | no |
| <a name="input_event_buses"></a> [event\_buses](#input\_event\_buses) | List of EventBridge buses and their rules/targets | <pre>list(object({<br/>    name = string<br/>    tags = optional(map(string))<br/>    rules = list(object({<br/>      name                = string<br/>      description         = string<br/>      event_pattern       = string<br/>      schedule_expression = optional(string)<br/>      is_enabled          = bool<br/>      tags                = optional(map(string))<br/>      targets = list(object({<br/>        id            = string<br/>        arn           = string<br/>        target_policy = optional(string)<br/>        dlq_arn       = optional(string)<br/>        retry_policy = optional(object({<br/>          maximum_event_age_in_seconds = optional(number)<br/>          maximum_retry_attempts       = optional(number)<br/>        }))<br/>        input_transformer = optional(object({<br/>          input_template = string<br/>          input_paths    = optional(map(string))<br/>        }))<br/>      }))<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_kms_cmk_arn"></a> [kms\_cmk\_arn](#input\_kms\_cmk\_arn) | KMS CMK ARN for CloudWatch Logs encryption | `string` | `""` | no |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | Name of the CloudWatch Log Group for EventBridge logging | `string` | `"/aws/events/default-log-group"` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention period for logs in CloudWatch | `number` | `14` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for IAM roles and policies | `string` | `"eb"` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | The AWS Organization ID allowed to send events to this bus | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Global tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_event_bus_arns"></a> [event\_bus\_arns](#output\_event\_bus\_arns) | Map of event bus names to ARNs |
| <a name="output_iam_role_arns"></a> [iam\_role\_arns](#output\_iam\_role\_arns) | Map of role identifiers to IAM role ARNs |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group name if logging is enabled |
| <a name="output_rule_arns"></a> [rule\_arns](#output\_rule\_arns) | Map of rule names to ARNs |
| <a name="output_rule_names"></a> [rule\_names](#output\_rule\_names) | List of all rule names |

