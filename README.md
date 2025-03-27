# Terraform AWS EventBridge Module

This Terraform module provisions:

- One or more **Amazon EventBridge buses**
- One or more **rules per bus**
- Multiple **targets per rule** (fan-out pattern)
- Associated **IAM roles and policies**
- Optional features:
  - Dead Letter Queues (DLQ)
  - Retry policies
  - Input transformers
  - CloudWatch log group for EventBridge

---

## Features

✅ Multi-bus support  
✅ Multi-rule support per bus  
✅ Multi-target support per rule  
✅ Cross-account organization-based access  
✅ Optional logging  
✅ KMS support ready (optional enhancement)  

---

## Usage

### Basic Multi-Bus + Multi-Rule Example

```hcl
module "eventbridge" {
  source = "./eventbridge"

  name_prefix = "app"
  tags = {
    environment = "prod"
    team        = "platform"
  }

  enable_logging        = true
  log_group_name        = "/aws/events/my-app"
  log_retention_in_days = 30

  event_buses = [
    {
      name = "app-bus"
      tags = { usage = "application-events" }

      rules = [
        {
          name          = "user-created"
          description   = "Trigger actions when a new user is created"
          event_pattern = jsonencode({ source = ["users.service"] })
          is_enabled    = true

          targets = [
            {
              id    = "lambda-trigger"
              arn   = aws_lambda_function.notify_user.arn
              target_policy = jsonencode({
                Version = "2012-10-17",
                Statement = [{
                  Effect   = "Allow",
                  Action   = "lambda:InvokeFunction",
                  Resource = aws_lambda_function.notify_user.arn
                }]
              })
              retry_policy = {
                maximum_event_age_in_seconds = 3600
                maximum_retry_attempts       = 3
              }
              input_transformer = {
                input_template = "{\"user_id\": <userId>}"
                input_paths = {
                  "userId" = "$.detail.user.id"
                }
              }
            }
          ]
        }
      ]
    }
  ]
}
```


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