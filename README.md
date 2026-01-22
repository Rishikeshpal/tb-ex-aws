# Terraform AWS Infrastructure

Production-ready AWS infrastructure setup with networking, database, load balancing, and auto-scaling. Built following AWS best practices and DRY principles using official Terraform modules.

## What's Included

- **Networking**: VPC with public/private subnet separation across 2 AZs
- **Database**: PostgreSQL RDS in private subnets (no public access)
- **Compute**: Auto Scaling Group with Nginx on Amazon Linux 2023
- **Load Balancing**: Application Load Balancer with health checks
- **CI/CD**: Smart pipeline that only runs Terraform on changed modules

## Architecture

```
                         Internet
                            │
                    ┌───────┴───────┐
                    │  Internet GW  │
                    └───────┬───────┘
                            │
           ┌────────────────┴────────────────┐
           │            VPC                  │
           │        192.168.0.0/16           │
           │                                 │
    ┌──────┴──────┐                ┌─────────┴─────────┐
    │   Public    │                │     Private       │
    │  Subnets    │                │     Subnets       │
    │             │                │                   │
    │    ALB      │───────────────▶│   EC2 (Nginx)    │
    │             │                │   ASG 1-3        │
    │  NAT GWs    │                │                   │
    └─────────────┘                │   PostgreSQL     │
                                   │   (RDS)          │
                                   └───────────────────┘
```

## Quick Start

```bash
# Clone and configure
cd terraform-aws-infrastructure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set your db_password and region

# Deploy
terraform init
terraform plan
terraform apply
```

## Project Layout

```
.
├── vpc.tf              # VPC module config (public/private subnets, NAT, IGW)
├── rds.tf              # PostgreSQL database
├── alb.tf              # Load balancer with target groups
├── asg.tf              # Launch template + Auto Scaling Group
├── security-groups.tf  # All security group definitions
├── variables.tf        # Input variables
├── outputs.tf          # Useful outputs (endpoints, IDs, etc.)
├── global/             # Shared infra (IAM, S3 state bucket)
├── apps/               # Service-specific modules
│   ├── payment-api/
│   └── user-api/
└── .github/workflows/  # CI/CD pipeline
```

## Configuration

Key variables you'll want to set:

| Variable | What it does | Default |
|----------|--------------|---------|
| `aws_region` | Where to deploy | us-east-1 |
| `project_name` | Prefix for all resources | webapp |
| `environment` | Environment tag (dev/staging/prod) | dev |
| `db_password` | RDS master password | *required* |
| `asg_min_size` | Minimum EC2 instances | 1 |
| `asg_max_size` | Maximum EC2 instances | 3 |

## Security Notes

A few things worth mentioning:

- RDS is in private subnets with `publicly_accessible = false`
- Database security group only allows connections from within the VPC (192.168.0.0/16)
- EC2 instances are in private subnets, only accessible through the ALB
- All EBS volumes and RDS storage are encrypted
- IMDSv2 is required on EC2 instances

## The CI/CD Pipeline

The pipeline is designed to avoid the "run everything on every change" problem. It detects what changed and only plans/applies the relevant modules.

**How it works:**

- Change `apps/payment-api/*` → only plan payment-api
- Change `apps/user-api/*` → only plan user-api
- Change `global/*` → plan ALL apps (to catch breaking changes)
- Change only `CHANGELOG.md` → skip Terraform entirely

This prevents race conditions on state files and speeds up CI significantly.

**Required GitHub Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Modules Used

Using official Terraform AWS modules to keep things maintainable:

- [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) - VPC, subnets, NAT gateways
- [terraform-aws-modules/alb/aws](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws) - Application Load Balancer

## Outputs

After `terraform apply`, you'll get:

- `alb_dns_name` - Hit this URL to see Nginx running
- `rds_endpoint` - Database connection string
- `vpc_id`, `public_subnet_ids`, `private_subnet_ids` - For reference

## Cleanup

```bash
terraform destroy
```

Note: `deletion_protection` is disabled by default for easy cleanup. Enable it for production.
