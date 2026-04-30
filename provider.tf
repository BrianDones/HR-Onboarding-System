terraform {

  required_version = ">= 1.11.0"
  
  backend "s3" {
    # This configuration is provided via the -backend-config flag when Terraform is initialized.
    # The reason we are loading in our configuration file from there is to secure details about
    # our S3 Terraform State bucket and our AWS Account ID. 
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "Terraform-User"
}