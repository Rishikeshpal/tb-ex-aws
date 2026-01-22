#------------------------------------------------------------------------------
# Data source for latest Amazon Linux 2023 AMI
#------------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

#------------------------------------------------------------------------------
# IAM Role for EC2 instances (SSM access for management)
#------------------------------------------------------------------------------
resource "aws_iam_role" "web" {
  name = "${var.project_name}-${var.environment}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-web-role"
  }
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project_name}-${var.environment}-web-profile"
  role = aws_iam_role.web.name
}

#------------------------------------------------------------------------------
# Launch Template for t3.micro Amazon Linux 2023 with Nginx
#------------------------------------------------------------------------------
resource "aws_launch_template" "web" {
  name          = "${var.project_name}-${var.environment}-web-lt"
  description   = "Launch template for web servers with Nginx"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # IAM Instance Profile for SSM access
  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  # Network configuration
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web.id]
    delete_on_termination       = true
  }

  # User Data to install and configure Nginx
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -ex

    # Update system packages
    dnf update -y

    # Install Nginx
    dnf install -y nginx

    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx

    # Create a custom index page
    cat > /usr/share/nginx/html/index.html <<'HTMLEOF'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Welcome to ${var.project_name}</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
            }
            .container {
                text-align: center;
                padding: 40px;
                background: rgba(255,255,255,0.1);
                border-radius: 10px;
                backdrop-filter: blur(10px);
            }
            h1 { font-size: 2.5em; margin-bottom: 20px; }
            p { font-size: 1.2em; opacity: 0.9; }
            .instance-id { 
                font-family: monospace; 
                background: rgba(0,0,0,0.2); 
                padding: 10px; 
                border-radius: 5px;
                margin-top: 20px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Welcome to ${var.project_name}</h1>
            <p>Application is running successfully!</p>
            <p class="instance-id">Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        </div>
    </body>
    </html>
    HTMLEOF

    # Restart Nginx to apply changes
    systemctl restart nginx

    # Signal that the instance is ready
    echo "User data script completed successfully"
  EOF
  )

  # Monitoring
  monitoring {
    enabled = true
  }

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # EBS optimized
  ebs_optimized = true

  # Block device mappings
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-web"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-${var.environment}-web-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-lt"
  }

  lifecycle {
    create_before_destroy = true
  }
}

#------------------------------------------------------------------------------
# Auto Scaling Group (min: 1, max: 3)
#------------------------------------------------------------------------------
resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-${var.environment}-web-asg"
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = local.private_subnet_ids

  # Integration with ALB Target Group
  target_group_arns = [module.alb.target_groups["web"].arn]

  # Launch Template
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Health check configuration
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Instance refresh for zero-downtime deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Termination policies
  termination_policies = ["OldestInstance", "Default"]

  # Wait for instances to be healthy before marking ASG as created
  wait_for_capacity_timeout = "10m"

  # Tags for instances
  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

#------------------------------------------------------------------------------
# Auto Scaling Policies (Optional - for dynamic scaling)
#------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

#------------------------------------------------------------------------------
# CloudWatch Alarms for Auto Scaling (Optional)
#------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Scale up when CPU exceeds 80%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale down when CPU falls below 20%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
