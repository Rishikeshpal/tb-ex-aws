# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial infrastructure setup with VPC, subnets, and RDS
- Application Load Balancer with Auto Scaling Group
- Smart CI/CD pipeline with conditional execution

## [1.0.0] - 2026-01-22

### Added
- VPC with CIDR 192.168.0.0/16
- 2 Public subnets across different AZs
- 2 Private subnets across different AZs
- Internet Gateway with public route table
- NAT Gateways for private subnet outbound access
- PostgreSQL RDS instance (db.t3.micro) in private subnets
- Security groups for ALB, web servers, and RDS
- Application Load Balancer using terraform-aws-modules
- Launch Template with Amazon Linux 2023 and Nginx
- Auto Scaling Group (min: 1, max: 3)
- Health check configuration for root path with 200 response
- Smart CI/CD pipeline with matrix execution
- Global IAM module for shared policies
- Global S3 module for state storage
- Payment API service module
- User API service module

### Security
- RDS only accepts traffic from VPC CIDR (not open internet)
- RDS placed in private subnets with no public accessibility
- All EBS volumes encrypted
- S3 buckets with server-side encryption and blocked public access
- IMDSv2 required for EC2 instances
