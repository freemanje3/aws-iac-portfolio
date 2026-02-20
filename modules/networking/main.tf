module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets   = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  private_subnets  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  database_subnets = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true 

  enable_dns_hostnames = true
  enable_dns_support   = true

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # ------------------------------------------------------------------------------
  # Security Telemetry: VPC Flow Logs
  # ------------------------------------------------------------------------------
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  
  # 60-second aggregation for rapid security alerting (Default is 600s/10m)
  flow_log_max_aggregation_interval    = 60 

  # Set to CloudWatch for now. When you build the logging account, 
  # we will change this to "s3" and point it across the AWS Organization.
  flow_log_destination_type            = "cloud-watch-logs"
}
