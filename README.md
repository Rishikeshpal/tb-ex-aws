# Terraform AWS Infrastructure

A comprehensive AWS infrastructure deployment with VPC, RDS PostgreSQL, ALB, Auto Scaling Group, and a Smart CI/CD Pipeline.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC (192.168.0.0/16)                           │
├─────────────────────────────────┬───────────────────────────────────────────┤
│         Public Subnets          │            Private Subnets                │
│  ┌─────────────┬─────────────┐  │  ┌─────────────┬─────────────┐           │
│  │ 192.168.1.0 │ 192.168.2.0 │  │  │ 192.168.3.0 │ 192.168.4.0 │           │
│  │    /24      │    /24      │  │  │    /24      │    /24      │           │
│  │   (AZ-1)    │   (AZ-2)    │  │  │   (AZ-1)    │   (AZ-2)    │           │
│  └──────┬──────┴──────┬──────┘  │  └──────┬──────┴──────┬──────┘           │
│         │             │         │         │             │                   │
│    ┌────┴─────────────┴────┐    │    ┌────┴─────────────┴────┐             │
│    │  Application Load     │    │    │   Auto Scaling Group  │             │
│    │     Balancer (ALB)    │    │    │   (EC2 with Nginx)    │             │
│    │       Port 80         │    │    │     t3.micro          │             │
│    └───────────────────────┘    │    │    min:1 max:3        │             │
│              │                  │    └───────────────────────┘             │
│              │                  │              │                            │
│    ┌─────────┴─────────┐        │              │                            │
│    │  Internet Gateway │        │    ┌─────────┴─────────┐                  │
│    └───────────────────┘        │    │  PostgreSQL RDS   │                  │
│                                 │    │   db.t3.micro     │                  │
│                                 │    │  (Private Only)   │                  │
│                                 │    └───────────────────┘                  │
└─────────────────────────────────┴───────────────────────────────────────────┘
```

## Project Structure

```
terraform-aws-infrastructure/
├── .github/
│   └── workflows/
│       └── pipeline.yml          # Smart CI/CD pipeline
├── global/
│   ├── iam/                      # Shared IAM policies
│   │   └── main.tf
│   └── s3/                       # Shared state storage
│       └── main.tf
├── apps/
│   ├── payment-api/              # Payment Service
│   │   └── main.tf
│   └── user-api/                 # User Service
│       └── main.tf
├── alb.tf                        # Application Load Balancer
├── asg.tf                        # Auto Scaling Group & Launch Template
├── outputs.tf                    # Output definitions
├── rds.tf                        # RDS PostgreSQL
├── security-groups.tf            # Security group definitions
├── variables.tf                  # Variable definitions
├── versions.tf                   # Provider configuration
├── vpc.tf                        # VPC, subnets, routing
├── terraform.tfvars.example      # Example variables
├── CHANGELOG.md                  # Change log
└── README.md                     # This file
```

## Part 1: Foundation (VPC, Subnets, RDS)

### VPC Configuration
- **CIDR Block:** 192.168.0.0/16
- **DNS Hostnames:** Enabled
- **DNS Support:** Enabled

### Subnets
| Type    | CIDR           | Availability Zone |
|---------|----------------|-------------------|
| Public  | 192.168.1.0/24 | us-east-1a       |
| Public  | 192.168.2.0/24 | us-east-1b       |
| Private | 192.168.3.0/24 | us-east-1a       |
| Private | 192.168.4.0/24 | us-east-1b       |

### Routing
- **Public Route Table:** Routes 0.0.0.0/0 → Internet Gateway
- **Private Route Tables:** Routes 0.0.0.0/0 → NAT Gateway (per AZ)

### RDS PostgreSQL
- **Instance Class:** db.t3.micro
- **Engine:** PostgreSQL 15.4
- **Placement:** Private subnets only
- **Security:** Accepts traffic only from VPC CIDR (192.168.0.0/16)
- **Publicly Accessible:** No

## Part 2: Application Layer (ALB, ASG, Nginx)

### Application Load Balancer
- Uses official `terraform-aws-modules/alb/aws` module
- HTTP listener on Port 80
- Deployed in public subnets

### Target Group Health Check
- **Path:** `/`
- **Expected Response:** 200
- **Interval:** 30 seconds
- **Healthy Threshold:** 2
- **Unhealthy Threshold:** 2

### Launch Template
- **AMI:** Amazon Linux 2023 (latest)
- **Instance Type:** t3.micro
- **User Data:** Installs and configures Nginx
- **IMDSv2:** Required
- **EBS:** Encrypted gp3 volumes

### Auto Scaling Group
- **Minimum:** 1 instance
- **Maximum:** 3 instances
- **Desired:** 1 instance
- **Health Check:** ELB-based
- **Auto Scaling Policies:** CPU-based (80% up, 20% down)

## Part 3: Smart CI/CD Pipeline

### Problem Solved
Prevents unnecessary Terraform plans and race conditions on state files by only running plans for changed modules.

### Conditional Execution Logic

| Change Detected | Action |
|-----------------|--------|
| `apps/payment-api/**` | Plan Payment API only |
| `apps/user-api/**` | Plan User API only |
| `global/iam/**` | Plan ALL apps (downstream check) |
| `global/s3/**` | Plan ALL apps (downstream check) |
| `CHANGELOG.md` only | Exit successfully, no Terraform |

### Pipeline Features
- **Matrix Execution:** Parallel plans for multiple apps
- **Job Summary:** Plan results visible in GitHub Actions summary
- **Concurrency Control:** Prevents race conditions on same branch
- **Artifact Upload:** Plan files saved for potential apply

## Usage

### Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket for remote state (for production)

### Quick Start

1. **Clone and configure:**
   ```bash
   cd terraform-aws-infrastructure
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Apply the infrastructure:**
   ```bash
   terraform apply
   ```

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | us-east-1 |
| `project_name` | Project identifier | webapp |
| `environment` | Environment name | dev |
| `db_password` | RDS master password | (required) |

### Outputs

After applying, you'll receive:
- VPC and subnet IDs
- RDS endpoint and connection info
- ALB DNS name
- ASG name

## Security Considerations

1. **RDS Security:**
   - Placed in private subnets
   - No public accessibility
   - Security group allows only VPC CIDR on port 5432

2. **EC2 Security:**
   - Placed in private subnets
   - Only accepts traffic from ALB security group
   - IMDSv2 required

3. **Encryption:**
   - RDS storage encrypted
   - EBS volumes encrypted
   - S3 buckets use server-side encryption

4. **Network Isolation:**
   - Public subnets: ALB only
   - Private subnets: EC2 instances and RDS

## CI/CD Pipeline Setup

1. **Required GitHub Secrets:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Pipeline Triggers:**
   - Push to `main` or `feature/**` branches
   - Pull requests to `main`

3. **Workflow File:** `.github/workflows/pipeline.yml`

## Cost Estimation

| Resource | Type | Estimated Monthly Cost |
|----------|------|------------------------|
| NAT Gateway | 2x | ~$65/month |
| RDS | db.t3.micro | ~$15/month |
| EC2 | t3.micro (1-3) | ~$8-24/month |
| ALB | Application | ~$16/month |
| **Total** | | **~$104-120/month** |

*Costs are estimates and may vary by region and usage.*

## License

MIT License - See LICENSE file for details.
