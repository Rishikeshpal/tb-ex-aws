#------------------------------------------------------------------------------
# Global IAM Policies and Roles
# This module contains shared IAM resources used across all applications
#------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state configuration (uncomment and configure for production)
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "global/iam/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "myproject"
}

#------------------------------------------------------------------------------
# Shared IAM Policy - S3 Access
#------------------------------------------------------------------------------
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-shared-s3-access"
  description = "Shared S3 access policy for all applications"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Shared IAM Role - Application Base Role
#------------------------------------------------------------------------------
resource "aws_iam_role" "app_base" {
  name = "${var.project_name}-app-base-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-app-base-role"
    ManagedBy = "Terraform"
    Module    = "global/iam"
  }
}

#------------------------------------------------------------------------------
# Outputs - Used by downstream modules
#------------------------------------------------------------------------------
output "s3_access_policy_arn" {
  description = "ARN of the shared S3 access policy"
  value       = aws_iam_policy.s3_access.arn
}

output "app_base_role_arn" {
  description = "ARN of the base application role"
  value       = aws_iam_role.app_base.arn
}

output "app_base_role_name" {
  description = "Name of the base application role"
  value       = aws_iam_role.app_base.name
}
