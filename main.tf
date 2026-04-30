# 1. DynamoDB Table that stores Employee information

resource "aws_dynamodb_table" "employees" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  # Enables the stream for the Slack Provisioner to listen to for events
  stream_enabled    = true
  stream_view_type = "NEW_IMAGE"
}

# 2. IAM Policies and Roles for our Lambda functions

# Lambda role for the HR Processor Lambda function
resource "aws_iam_role" "hr_processor_role" {
  name = "hr-processor-role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        }
      ]
    }
  )
}

# HR Processor Policy to allow Lambda to: 
# - Write to the Employees DynamoDB table
# - Create and update Log Groups/streams with important messages from lambda executions
resource "aws_iam_role_policy" "hr_processor_policy" {
  name = "hr-processor-policy"
  role = aws_iam_role.hr_processor_role.id
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:PutItem",
            "dynamodb:GetItem"
          ]
          Resource = aws_dynamodb_table.employees.arn
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:*:*:*"
        }
      ]
    }
  )
}  

# Lambda role for the Slack Provisioner Lambda function
resource "aws_iam_role" "slack_provisioner_role" {
  name = "slack-provisioner-role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "lambda.amazonaws.com" }
        }
      ]
    }
  )
}

# Slack Provisioner Policy to allow Lambda to:
# - Listen for activity on the DynamoDB Stream to trigger the provisioner
# - Update the Slack Status in the Employees DynamoDB table after a Slack Invitation is sent
# - Retrieve the secret from Secrets Manager
# - Create and update Log Groups/streams with important messages from the lambda execution
resource "aws_iam_role_policy" "slack_provisioner_policy" {
  name = "slack-provisioner-policy"
  role = aws_iam_role.slack_provisioner_role.id
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetRecords",
            "dynamodb:GetShardIterator",
            "dynamodb:DescribeStream",
            "dynamodb:ListStreams"
          ]
          Resource = [
            "${aws_dynamodb_table.employees.arn}/*/*",
            "${aws_dynamodb_table.employees.stream_arn}",
            "${aws_dynamodb_table.employees.stream_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:UpdateItem"
          ]
          Resource = "${aws_dynamodb_table.employees.arn}"
        },
        {
          Effect = "Allow"
          Action = "secretsmanager:GetSecretValue"
          Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.slack_secret_name}-*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:*:*:*"
        }
      ]
    }
  )
}