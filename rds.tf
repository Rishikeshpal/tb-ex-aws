#------------------------------------------------------------------------------
# RDS Subnet Group - Places database in Private Subnets
#------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Database subnet group for RDS"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

#------------------------------------------------------------------------------
# RDS PostgreSQL Instance
#------------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  # Engine configuration
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network configuration - PRIVATE SUBNETS ONLY
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # Ensures DB is NOT accessible from internet

  # Multi-AZ for high availability (optional for production)
  multi_az = false

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Performance and monitoring
  performance_insights_enabled = false
  monitoring_interval          = 0

  # Deletion protection (set to true for production)
  deletion_protection = false
  skip_final_snapshot = true

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
  }
}

#------------------------------------------------------------------------------
# RDS Parameter Group
#------------------------------------------------------------------------------
resource "aws_db_parameter_group" "postgres" {
  family = "postgres15"
  name   = "${var.project_name}-${var.environment}-postgres-params"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres-params"
  }
}
