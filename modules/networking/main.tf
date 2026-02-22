module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  # Your 4 AZs
  azs              = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
  
  public_subnets   = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  private_subnets  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  database_subnets = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]
  
  # Your brand new perfectly isolated tier
  intra_subnets    = ["10.0.41.0/24", "10.0.42.0/24", "10.0.43.0/24", "10.0.44.0/24"]

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

# ------------------------------------------------------------------------------
# ISOLATED DB SUBNET GROUP (For Multi-AZ RDS)
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "isolated_db_group" {
  name       = "${var.environment}-isolated-db-group"
  
  # This dynamically grabs the 4 new isolated subnets from the module!
  subnet_ids = module.vpc.intra_subnets

  tags = {
    Name = "${var.environment}-isolated-db-group"
  }


# ------------------------------------------------------------------------------
# GATEWAY VPC ENDPOINTS (S3 & DynamoDB)
# ------------------------------------------------------------------------------

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  
  # Automatically injects the S3 route into both Private and Isolated tiers!
  route_table_ids   = flatten([
    module.vpc.intra_route_table_ids,
    module.vpc.private_route_table_ids
  ])
  
  tags = {
    Name = "${var.environment}-s3-gateway-endpoint"
    Tier = "Isolated"
  }
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids   = flatten([
    module.vpc.intra_route_table_ids,
    module.vpc.private_route_table_ids
  ])
  
  tags = {
    Name = "${var.environment}-dynamodb-gateway-endpoint"
    Tier = "Isolated"
  }
}