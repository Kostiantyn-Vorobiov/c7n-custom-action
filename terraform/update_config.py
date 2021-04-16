import json
import boto3


def update_secret(client, secret_name, value):
  secret_found = False
  response = client.list_secrets()
  secrets = response["SecretList"]
  secret_json = None
  for secret in secrets:
      if secret['Name'] == secret_name:
          secret_found = True
          break
  secret_value = json.dumps(value)
  if secret_found:
      response = client.update_secret(SecretId=secret_name,
                                      SecretString=secret_value)
  else:
      response = client.create_secret(Name=secret_name,
                                      SecretString=secret_value)
  return response


slack_webhook = input("\nINPUT: Enter the Slack Webhook to send notifications (eg: 'https://hooks.slack.com/services/xyzxyzxyzxyz...'): ")
slack_webhook = slack_webhook.strip()
aws_profile = input("\nINPUT: If you are using an AWS profile, enter its name (otherwise keep it empty): ")
aws_region = input("\nINPUT: Enter AWS region to use (default: 'us-west-2'): ") or "us-west-2"
aws_region = aws_region.strip()

secret_prefix = "c7n"
app_config = {
  'slack_webhook': slack_webhook,
}


if aws_profile:
  session = boto3.Session(region_name=aws_region,profile_name=aws_profile)
else:
  session = boto3.Session(region_name=aws_region)

client = session.client('secretsmanager')
response = update_secret(client, f'{secret_prefix}-config',
                         app_config)