# 1. Define the AWS Provider
terraform {
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

# 2. Call the Backend / OIDC Module
module "backend" {
  source = "./modules/backend"
}

# 3. Call the Security / Observability Module
module "security" {
  source = "./modules/security"
}

# 4. Call the Networking Module (Since you mentioned the VPC is already built!)
module "networking" {
  source = "./modules/networking"
}
