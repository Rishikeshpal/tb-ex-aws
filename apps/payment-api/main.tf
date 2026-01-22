#------------------------------------------------------------------------------
# Payment API Service
# This module deploys the Payment API infrastructure
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
  #   key            = "apps/payment-api/terraform.tfstate"
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
      Service     = "payment-api"
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
# Payment API Specific Resources
#------------------------------------------------------------------------------

# Example: Payment API Lambda Function
resource "aws_lambda_function" "payment_processor" {
  function_name = "${var.project_name}-${var.environment}-payment-processor"
  role          = aws_iam_role.payment_api.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30
  memory_size   = 256

  # Placeholder - in production, use S3 or container image
  filename = "${path.module}/placeholder.zip"

  environment {
    variables = {
      ENVIRONMENT = var.environment
      SERVICE     = "payment-api"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-payment-processor"
  }

  lifecycle {
    ignore_changes = [filename]
  }
}

# IAM Role for Payment API Lambda
resource "aws_iam_role" "payment_api" {
  name = "${var.project_name}-${var.environment}-payment-api-role"

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
resource "aws_iam_role_policy_attachment" "payment_api_basic" {
  role       = aws_iam_role.payment_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway for Payment API
resource "aws_apigatewayv2_api" "payment" {
  name          = "${var.project_name}-${var.environment}-payment-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-payment-api"
  }
}

resource "aws_apigatewayv2_stage" "payment" {
  api_id      = aws_apigatewayv2_api.payment.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.payment_api.arn
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
resource "aws_cloudwatch_log_group" "payment_api" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-payment-api"
  retention_in_days = 14
}

#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------
output "api_endpoint" {
  description = "Payment API endpoint URL"
  value       = aws_apigatewayv2_api.payment.api_endpoint
}

output "lambda_function_name" {
  description = "Payment processor Lambda function name"
  value       = aws_lambda_function.payment_processor.function_name
}

output "lambda_function_arn" {
  description = "Payment processor Lambda function ARN"
  value       = aws_lambda_function.payment_processor.arn
}
