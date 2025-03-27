provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

module "cross_account_sender" {
  source      = "../.."
  name_prefix = "sender"

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
          event_pattern = jsonencode({ account = ["${data.aws_caller_identity.current.account_id}"] })

          targets = [
            {
              id  = "receiver-default-bus"
              arn = "arn:aws:events:us-east-1:194722401531:event-bus/default"

              target_policy = jsonencode({
                Version = "2012-10-17",
                Statement = [
                  {
                    Effect   = "Allow",
                    Action   = "events:PutEvents",
                    Resource = "arn:aws:events:us-east-1:194722401531:event-bus/default"
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
