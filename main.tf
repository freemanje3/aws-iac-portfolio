terraform {
  # This tells GitHub Actions where to find your infrastructure map!
  backend "s3" {
    bucket         = "jamesfreeman-cmk-secure-state-99999"
    key            = "portfolio/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks-secure"
    encrypt        = true
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

# Execute all modules
module "backend" {
  source = "./modules/backend"
}

module "security" {
  source = "./modules/security"
}

module "networking" {
  source = "./modules/networking"
}

module "compute" {
  source     = "./modules/compute"
  storage_kms_key_arn = module.security.general_storage_kms_key_arn
}