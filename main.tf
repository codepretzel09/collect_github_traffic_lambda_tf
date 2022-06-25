provider "aws" {
  region = var.aws_region
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"


    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }


    actions = ["sts:AssumeRole"]
  }
}

# Define where the code is located
locals {
  my_function_source = "github-traffic-collector.zip"
}



# create bucket
resource "aws_s3_bucket" "b1" {

  bucket = "github-traffic-lambda"
  acl    = "private" # or can be "public-read"
  tags = {
    Name        = "Github Traffic Lambda Function"
    Environment = "Dev"
  }

}

# Upload an object
resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.b1.id
  key    = "github-traffic-collector.zip"
  acl    = "private"
  source = local.my_function_source


}

# Create Lambda Function
resource "aws_iam_role" "lambda_github_traffic" {
  name               = "lambda_github_traffic"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}


resource "aws_lambda_function" "lambda" {
  function_name = "github-traffic-collector"

  role      = aws_iam_role.lambda_github_traffic.arn
  handler   = "github-traffic-collector.lambda_handler"
  runtime   = "python3.8"
  timeout   = "20"
  s3_bucket = aws_s3_bucket.b1.id
  s3_key    = "github-traffic-collector.zip"


}

# create cloudwatch event

resource "aws_cloudwatch_event_rule" "lambda-github-traffic" {
  name                = "lambda-github-traffic"
  description         = "Fires every night at 2:15AM"
  schedule_expression = "cron(24 3 * * ? *)"
}


resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.lambda-github-traffic.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda.arn
}


resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda-github-traffic.arn
}

