#------------------------------------------------------------------------------
# VPC Outputs (from module)
#------------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.vpc.natgw_ids
}

#------------------------------------------------------------------------------
# Security Group Outputs
#------------------------------------------------------------------------------
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "web_security_group_id" {
  description = "Security group ID for web servers"
  value       = aws_security_group.web.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

#------------------------------------------------------------------------------
# RDS Outputs
#------------------------------------------------------------------------------
output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "Name of the database"
  value       = aws_db_instance.postgres.db_name
}

#------------------------------------------------------------------------------
# ALB Outputs
#------------------------------------------------------------------------------
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value       = module.alb.target_groups
}

#------------------------------------------------------------------------------
# ASG Outputs
#------------------------------------------------------------------------------
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.web.id
}
