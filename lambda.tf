resource "aws_iam_role" "lambdaStopInstances" {
  name = "lambdaStopInstances"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sts:AssumeRole"
        ],
        "Principal" : {
          "Service" : [
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambdaEC2policy" {
  name = "lambdaEC2policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
        "Effect" : "Allow",
        "Resource" : "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "lambdaRolePolicyAttachment" {
  policy_arn = aws_iam_policy.lambdaEC2policy.arn
  roles      = [aws_iam_role.lambdaStopInstances.name]
  name       = "lambdaRolePolicyAttachment"
}

data "archive_file" "lambdaFile" {
  type        = "zip"
  source_file = "${path.module}/lambda.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "stoInstances" {
  role             = aws_iam_role.lambdaStopInstances.arn
  filename         = data.archive_file.lambdaFile.output_path
  function_name    = "stoInstances"
  runtime          = "python3.9"
  handler          = "lambda.lambda_handler"
  timeout          = 60
  source_code_hash = data.archive_file.lambdaFile.output_base64sha256

}

resource "aws_cloudwatch_event_rule" "stopRule" {
  name                = "stopRule"
  description         = "Rule to trigger lambda to stop all instances at a specific time"
  schedule_expression = "cron(41 15 * * ? *)"
}

resource "aws_cloudwatch_event_target" "stop_lambda_target" {
  rule      = aws_cloudwatch_event_rule.stopRule.name
  arn       = aws_lambda_function.stoInstances.arn
  target_id = "stop_lambda_target"
}

resource "aws_lambda_permission" "ec2_stop_perm" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stoInstances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stopRule.arn
}
