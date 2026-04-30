# 1. DynamoDB Table that stores Employee information

resource "aws_dynamodb_table" "employees" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "CompanyEmail"
    type = "S"
  }

  global_secondary_index {
    name            = "CompanyEmailIndex"
    hash_key        = "CompanyEmail"
    projection_type = "ALL"
  }

  # Enables the stream for the Slack Provisioner to listen to for events
  stream_enabled   = true
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
          Action = "sts:AssumeRole"
          Effect = "Allow"
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
            "dynamodb:GetItem",
            "dynamodb:Scan"
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
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:Query"
          ]
          Resource = [
            "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/${var.table_name}/index/CompanyEmailIndex"
          ]
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
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
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

# 3. API Gateway Resources
# Main Employee API
resource "aws_api_gateway_rest_api" "employees_api" {
  name        = "EmployeesAPI-v${var.application_version}"
  description = "API for the HR Onboarding System for new employees"
}

resource "aws_api_gateway_resource" "employee_resource" {
  rest_api_id = aws_api_gateway_rest_api.employees_api.id
  parent_id   = aws_api_gateway_rest_api.employees_api.root_resource_id
  path_part   = "employees"
}

# POST Method
resource "aws_api_gateway_method" "post_employee" {
  rest_api_id   = aws_api_gateway_rest_api.employees_api.id
  resource_id   = aws_api_gateway_resource.employee_resource.id
  http_method   = "POST"
  authorization = "None"
}

# POST Method Integration
resource "aws_api_gateway_integration" "post_employee_integration" {
  rest_api_id             = aws_api_gateway_rest_api.employees_api.id
  resource_id             = aws_api_gateway_resource.employee_resource.id
  http_method             = aws_api_gateway_method.post_employee.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hr_processor.invoke_arn

  depends_on = [aws_api_gateway_method.post_employee]
}

# API Gateway Deployment & Stage
# For information regarding API Gateway Deployments and Stages, 
# please refer to Amazon's documentation: 
# https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-stages.html

resource "aws_api_gateway_deployment" "employee_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.employees_api.id

  # Ensures that a redeployment occurs when the API configurations change
  # for our POST method
  triggers = {
    redeployment = sha1(jsonencode(
      [
        aws_api_gateway_method.post_employee.id
      ]
    ))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post_employee_integration
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.employee_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.employees_api.id
  stage_name    = var.environment
}

# 4. Lambda Functions

# Lambda expects code to be in zip format so we are having
# Terraform handle automating zipping the Python source code 
# for our Lambda functions. 
data "archive_file" "lambda_functions_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"
  output_path = "${path.module}/lambda_functions_code.zip"
}

# HR Processor Lambda Function used to: 
# - Add new employees to the employees database
# - Generate a unique user id for employees
resource "aws_lambda_function" "hr_processor" {
  filename         = data.archive_file.lambda_functions_zip.output_path
  source_code_hash = data.archive_file.lambda_functions_zip.output_base64sha256
  function_name    = "hr_processor"
  role             = aws_iam_role.hr_processor_role.arn
  handler          = "hr-processor-function.handler"
  runtime          = "python3.13"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.employees.name
    }
  }

  depends_on = [aws_iam_role_policy.hr_processor_policy]
}

# 5. API Gateway Permissions to Invote Lambda Functions
resource "aws_lambda_permission" "apigw_hr_processor_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hr_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.employees_api.execution_arn}/*/*"

  depends_on = [aws_api_gateway_deployment.employee_api_deployment]
}