variable "aws_region" {
  description = "The AWS Region we are using the deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The type of environment resources will deployed in. e.g. Production, Staging, etc."
  type        = string
  default     = "staging"
}

variable "table_name" {
  description = "Name of the Employee Information DynamoDB table"
  type        = string
  default     = "EmployeesTable"
}

variable "slack_secret_name" {
  description = "The name of the secret in AWS Secrets Manager"
  type        = string
  default     = "slack/token"
}

variable "application_version" {
  description = "The version of our HR Onboarding System"
  type        = string
  default     = "0"
}

variable "account_id" {
  description = "The AWS Account ID"
  type        = string
  default     = ""
}