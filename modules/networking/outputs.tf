# ------------------------------------------------------------------------------
# VPC FOUNDATION OUTPUTS
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The foundational CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# ------------------------------------------------------------------------------
# SUBNET TIERS (For Cross-Module Routing)
# ------------------------------------------------------------------------------
output "public_subnets" {
  description = "List of IDs of public subnets (Target for ALBs and NAT Gateways)"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of IDs of private subnets (Target for Application EC2/Compute)"
  value       = module.vpc.private_subnets
}

output "isolated_subnets" {
  description = "List of IDs of strictly isolated/intra subnets (Target for VPC Endpoints)"
  value       = module.vpc.intra_subnets
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnets
}

# ------------------------------------------------------------------------------
# DATABASE ROUTING
# ------------------------------------------------------------------------------
output "isolated_db_subnet_group_name" {
  description = "The name of the explicitly isolated DB subnet group for Multi-AZ RDS"
  value       = aws_db_subnet_group.isolated_db_group.name
}

# ------------------------------------------------------------------------------
# SECURITY & TELEMETRY
# ------------------------------------------------------------------------------
output "vpc_flow_log_cloudwatch_iam_role_arn" {
  description = "The ARN of the IAM role used for VPC Flow Logs"
  value       = module.vpc.vpc_flow_log_cloudwatch_iam_role_arn
}

output "vpc_flow_log_destination_arn" {
  description = "The ARN of the destination for VPC Flow Logs"
  value       = module.vpc.vpc_flow_log_destination_arn
}