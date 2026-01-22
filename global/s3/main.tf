#------------------------------------------------------------------------------
# Global S3 - Shared State Storage
# This module contains S3 buckets for Terraform state and shared resources
#------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Note: This is the bootstrap module - state stored locally or in separate bucket
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "global/s3/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
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
# Terraform State Bucket
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state"

  tags = {
    Name      = "${var.project_name}-terraform-state"
    Purpose   = "Terraform State Storage"
    ManagedBy = "Terraform"
    Module    = "global/s3"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#------------------------------------------------------------------------------
# DynamoDB Table for State Locking
#------------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.project_name}-terraform-locks"
    Purpose   = "Terraform State Locking"
    ManagedBy = "Terraform"
    Module    = "global/s3"
  }
}

#------------------------------------------------------------------------------
# Shared Artifacts Bucket
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-shared-artifacts"

  tags = {
    Name      = "${var.project_name}-shared-artifacts"
    Purpose   = "Shared Application Artifacts"
    ManagedBy = "Terraform"
    Module    = "global/s3"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

#------------------------------------------------------------------------------
# Outputs - Used by downstream modules
#------------------------------------------------------------------------------
output "state_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "locks_table_name" {
  description = "Name of the DynamoDB locks table"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "artifacts_bucket_name" {
  description = "Name of the shared artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the shared artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}
