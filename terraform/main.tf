locals {
    name = "c7n"
    tags = {}
    slack_webhook      = var.slack_webhook != "" ? var.slack_webhook : jsondecode(data.aws_secretsmanager_secret_version.app.secret_string)["slack_webhook"]
}

data "aws_secretsmanager_secret" "app" {
  name = "${local.name}-config"
}

data "aws_secretsmanager_secret_version" "app" {
  secret_id = data.aws_secretsmanager_secret.app.id
}

module "notify_slack" {
  source  = "terraform-aws-modules/notify-slack/aws"
  version = "~> 3.5.0"

  sns_topic_name                         = "${local.name}-slack-notifier"
  lambda_function_name                   = "${local.name}-slack-notifier"
  slack_webhook_url                      = local.slack_webhook
  slack_channel                          = var.slack_channel
  slack_username                         = local.name
  slack_emoji                            = ":fire:"
  tags                                   = merge(var.tags, local.tags)
  cloudwatch_log_group_retention_in_days = 14
}

#module.notify_slack.this_slack_topic_arn