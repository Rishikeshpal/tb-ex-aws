#------------------------------------------------------------------------------
# Application Load Balancer using Official terraform-aws-modules Library
# https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest
#------------------------------------------------------------------------------
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.project_name}-${var.environment}-alb"
  load_balancer_type = "application"
  vpc_id             = local.vpc_id
  subnets            = local.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  # Enable deletion protection in production
  enable_deletion_protection = false

  # Access logs (optional - uncomment and configure S3 bucket for production)
  # access_logs = {
  #   bucket = "my-alb-logs-bucket"
  #   prefix = "${var.project_name}-${var.environment}"
  # }

  # Listeners
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "web"
      }
    }
  }

  # Target Groups with Health Check configuration
  target_groups = {
    web = {
      name             = "${var.project_name}-${var.environment}-web-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"

      # Health Check - checks root path and expects 200 response
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
      }

      # Deregistration delay
      deregistration_delay = 30

      # Stickiness (optional)
      stickiness = {
        enabled         = false
        type            = "lb_cookie"
        cookie_duration = 86400
      }

      # Note: Instances are registered via ASG target_group_arns
      create_attachment = false
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}
