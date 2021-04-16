resource "null_resource" "apply-policies" {
  provisioner "local-exec" {
    command = "/bin/sh ${path.module}/apply-policies.sh"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_iam_role.c7n_policy_role]
}


resource "aws_iam_policy" "c7n_policy" {
  name        = "${local.name}-main-policy"
  description = "IAM policy used by Lambda function in charge of managing c7n"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "*"
              ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "c7n_policy_role" {
  name        = "${local.name}-limit-ec2"
  description = "IAM role used by Lambda function in charge of managing c7n"

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

resource "aws_iam_role_policy_attachment" "c7n-policy-role" {
  role       = aws_iam_role.c7n_policy_role.name
  policy_arn = aws_iam_policy.c7n_policy.arn
}