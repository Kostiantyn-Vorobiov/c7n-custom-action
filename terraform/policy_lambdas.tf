module "ec2limit" {
  source = "../ec2limit"
  snsARN = module.notify_slack.this_slack_topic_arn
}