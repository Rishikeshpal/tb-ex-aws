#------------------------------------------------------------------------------
# User API Service
# This module deploys the User API infrastructure
#------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state configuration
  # backend "s3" {
  #   bucket         = "myproject-terraform-state"
  #   key            = "apps/user-api/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "myproject-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Service     = "user-api"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------
variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "myproject"
}

variable "environment" {
  default = "dev"
}

#------------------------------------------------------------------------------
# Data Sources - Reference Global Infrastructure
#------------------------------------------------------------------------------
data "terraform_remote_state" "global_iam" {
  backend = "s3"
  config = {
    bucket = "${var.project_name}-terraform-state"
    key    = "global/iam/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "global_s3" {
  backend = "s3"
  config = {
    bucket = "${var.project_name}-terraform-state"
    key    = "global/s3/terraform.tfstate"
    region = var.aws_region
  }
}

#------------------------------------------------------------------------------
# User API Specific Resources
#------------------------------------------------------------------------------

# Example: User API Lambda Function
resource "aws_lambda_function" "user_service" {
  function_name = "${var.project_name}-${var.environment}-user-service"
  role          = aws_iam_role.user_api.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30
  memory_size   = 256

  # Placeholder - in production, use S3 or container image
  filename = "${path.module}/placeholder.zip"

  environment {
    variables = {
      ENVIRONMENT = var.environment
      SERVICE     = "user-api"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-user-service"
  }

  lifecycle {
    ignore_changes = [filename]
  }
}

# IAM Role for User API Lambda
resource "aws_iam_role" "user_api" {
  name = "${var.project_name}-${var.environment}-user-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach base policies
resource "aws_iam_role_policy_attachment" "user_api_basic" {
  role       = aws_iam_role.user_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB Table for User Data
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-${var.environment}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-users"
  }
}

# IAM Policy for DynamoDB Access
resource "aws_iam_policy" "user_api_dynamodb" {
  name        = "${var.project_name}-${var.environment}-user-api-dynamodb"
  description = "Allow User API to access DynamoDB users table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          "${aws_dynamodb_table.users.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "user_api_dynamodb" {
  role       = aws_iam_role.user_api.name
  policy_arn = aws_iam_policy.user_api_dynamodb.arn
}

# API Gateway for User API
resource "aws_apigatewayv2_api" "user" {
  name          = "${var.project_name}-${var.environment}-user-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-user-api"
  }
}

resource "aws_apigatewayv2_stage" "user" {
  api_id      = aws_apigatewayv2_api.user.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.user_api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "user_api" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-user-api"
  retention_in_days = 14
}

#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------
output "api_endpoint" {
  description = "User API endpoint URL"
  value       = aws_apigatewayv2_api.user.api_endpoint
}

output "lambda_function_name" {
  description = "User service Lambda function name"
  value       = aws_lambda_function.user_service.function_name
}

output "lambda_function_arn" {
  description = "User service Lambda function ARN"
  value       = aws_lambda_function.user_service.arn
}

output "dynamodb_table_name" {
  description = "Users DynamoDB table name"
  value       = aws_dynamodb_table.users.name
}

output "dynamodb_table_arn" {
  description = "Users DynamoDB table ARN"
  value       = aws_dynamodb_table.users.arn
}
