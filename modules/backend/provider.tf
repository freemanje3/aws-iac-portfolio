terraform {
  backend "s3" {
    bucket         = "jamesfreeman-cmk-secure-state-99999"
    key            = "backend/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks-secure"
    encrypt        = true
    # This ensures Terraform encrypts the state file with your specific CMK
    kms_key_id     = "arn:aws:kms:us-east-1:555235820755:key/d2ad0de4-d141-4413-a2cf-47e107d697a6" 
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}