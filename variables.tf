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