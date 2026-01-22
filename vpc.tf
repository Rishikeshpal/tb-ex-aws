#------------------------------------------------------------------------------
# VPC using Official terraform-aws-modules Library
# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
#------------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # NAT Gateway configuration - one per AZ for high availability
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs (optional - uncomment for production)
  # enable_flow_log                      = true
  # create_flow_log_cloudwatch_log_group = true
  # create_flow_log_cloudwatch_iam_role  = true

  # Tags for subnet discovery (useful for EKS/ALB)
  public_subnet_tags = {
    Type                     = "Public"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    Type                              = "Private"
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
  }
}

#------------------------------------------------------------------------------
# Local values for easy reference throughout the configuration
#------------------------------------------------------------------------------
locals {
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets
}
