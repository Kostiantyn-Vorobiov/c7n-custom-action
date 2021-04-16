locals {
  name = "cc"
  tags = {}
}

resource "aws_iam_policy" "lambda_limit_ec2" {
  name        = "${local.name}-limit-ec2"
  description = "IAM policy used by Lambda function in charge of limiting ec2 instances"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": "${var.snsARN}"
        },
        {
            "Effect": "Allow",
            "Action": [
              "ec2:*"
              ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "${aws_cloudwatch_log_group.lambda_limit_ec2.arn}*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "lambda_limit_ec2" {
  name        = "${local.name}-limit-ec2"
  description = "IAM role used by Lambda function in charge of limiting ec2 instances"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_limit_ec2" {
  role       = aws_iam_role.lambda_limit_ec2.name
  policy_arn = aws_iam_policy.lambda_limit_ec2.arn
}

data "archive_file" "lambda_limit_ec2_zip" {
  type        = "zip"
  source_file = "${path.module}/ec2limit.py"
  output_path = "${path.module}/${local.name}-limit_ec2.zip"
}

# Creates a Lambda function

resource "aws_lambda_function" "limit_ec2" {
  filename      = data.archive_file.lambda_limit_ec2_zip.output_path
  function_name = "${local.name}-limit-ec2"
  role          = aws_iam_role.lambda_limit_ec2.arn
  handler       = "ec2limit.lambda_handler"

  source_code_hash = filebase64sha256(data.archive_file.lambda_limit_ec2_zip.output_path)

  environment {
    variables = {
      LOG_LEVEL = "DEBUG",
      snsARN = var.snsARN
    }
  }

  runtime = "python3.8"

  tags = merge(var.tags, local.tags)
}

resource "aws_cloudwatch_log_group" "lambda_limit_ec2" {
  name              = "/aws/lambda/${aws_lambda_function.limit_ec2.function_name}"
  retention_in_days = 14
}