output "api_endpoint" {
  description = "The URL of the API Gateway that HR users will use to add new employees"
  value       = "${aws_api_gateway_stage.stage.invoke_url}/employees"
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table storing employee information"
  value       = aws_dynamodb_table.employees.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.employees.arn
}

output "hr_processor_lambda_name" {
  description = "The name of the HR Processor Lambda function"
  value       = aws_lambda_function.hr_processor.function_name
}

output "hr_processor_role_arn" {
  description = "The ARN of the IAM role for the HR Processor"
  value       = aws_iam_role.hr_processor_role.arn
}