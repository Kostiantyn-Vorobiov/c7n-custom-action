import boto3
from datetime import datetime
import json
import logging
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

running_instances_metric_name = 'NumberRunningInstances'
orphan_eips_metric_name = 'NumberOrphanElasticIps'
metric_namespace = 'EC2'


def lambda_handler(event, context):
    logger.setLevel(os.environ.get('LOG_LEVEL', 'DEBUG'))
    logger.debug(event)
    ec2 = boto3.resource('ec2')
    limit = get_limit(event)
    ec2_types = get_ec2_type(event)
    timestamp = datetime.utcnow()
    instances = get_running_instances(ec2, ec2_types)
    num_instances = count_instances(instances)
    #cloudwatch = boto3.client('cloudwatch')
    #publish_metrics(cloudwatch, timestamp, num_instances)
    logger.info(
        f"Observed {num_instances} instances of {ec2_types} running at {timestamp} with limit {limit}")
    if num_instances > limit:
        execute_policy(event)
    return 200


def get_running_instances(ec2, ec2_types):
    instances = ec2.instances.filter(Filters=[
        {
            'Name': 'instance-state-name',
            'Values': [
                'running',
            ]
        },
        {
            'Name': 'instance-type',
            'Values': ec2_types
        },
    ])
    return instances


def count_instances(instances) -> int:
    total_instances = 0
    for _ in instances:
        total_instances += 1
    return total_instances


def get_limit(event) -> int:
    limit = 0
    try:
        limit = int(event['action']['vars']['limit'])
    except:
        logger.error("Failed to get EC2 limit")
    return limit


def get_action(event) -> str:
    action = ""
    try:
        action = str(event['action']['vars']['action'])
    except:
        logger.error(
            "Failed to load action for the instances that exceed the limit")
    return action


def get_ec2_type(event) -> list:
    ec2_types = []
    for filter in event['policy']['filters']:
        if filter.get('key', '') == 'InstanceType':
            logger.debug(f"filter value - {filter['value']}")
            ec2_types.extend(filter['value'])
    return ec2_types


def get_instance_ids(event) -> list:
    ids = []
    for instance in event['resources']:
        ids.append(instance.get('InstanceId', ''))
    if not ids:
        logger.info("No instance ids found in the event data")
    return ids


def publish_metrics(cloudwatch, timestamp, num_instances):
    cloudwatch.put_metric_data(
        Namespace=metric_namespace,
        MetricData=[
            {
                'MetricName': running_instances_metric_name,
                'Timestamp': timestamp,
                'Value': num_instances,
                'Unit': 'Count',
            },
            {
                'MetricName': orphan_eips_metric_name,
                'Timestamp': timestamp,
                'Value': None,
                'Unit': 'Count',
            },
        ]
    )


def execute_policy(event, dryrun=False):
    action = get_action(event)
    instances = get_instance_ids(event)
    ec2 = boto3.client('ec2')
    response = {}
    if action == "notify":
        notify(f"EC2 instances limit exceeded by {instances}")
    elif action == "stop":
        response = ec2.stop_instances(
            InstanceIds=instances,
            Hibernate=False,
            DryRun=dryrun,
            Force=True
        )
        notify(f"EC2 instances limit exceeded. Stopping instances {instances}")
    elif action == "terminate":
        response = ec2.terminate_instances(
            InstanceIds=instances,
            DryRun=dryrun
        )
        notify(
            f"EC2 instances limit exceeded. Terminating instances {instances}")
    return response


def get_sns_client():
    return boto3.client('sns')


def notify(message):
    logger.info(message)
    sns_arn = os.environ['snsARN']
    snsclient = get_sns_client()
    try:
        response = snsclient.publish(
            TargetArn=sns_arn,
            Subject=f"C7n policy",
            Message=message
        )
    except:
        logger.error("Failed to send message")
    return response


if __name__ == '__main__':
    lambda_handler({}, {})
