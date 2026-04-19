resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = [for subnet in aws_subnet.private_db : subnet.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-db-subnets"
    },
  )
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group for the encrypted PostgreSQL instance."
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Allow return traffic inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-db-sg"
    },
  )
}

resource "random_string" "snapshot_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name_prefix}/database/master"
  description             = "Master credentials for the encrypted PostgreSQL database."
  kms_key_id              = aws_kms_key.hipaa.arn
  recovery_window_in_days = var.production_safeguards ? 30 : 0

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "rds_postgresql" {
  name              = "/aws/rds/instance/${local.name_prefix}-postgres/postgresql"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.hipaa.arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "rds_upgrade" {
  name              = "/aws/rds/instance/${local.name_prefix}-postgres/upgrade"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.hipaa.arn

  tags = local.common_tags
}

resource "aws_db_parameter_group" "postgres" {
  name        = "${local.name_prefix}-postgres"
  family      = "postgres16"
  description = "Forces TLS and aligns PostgreSQL with HIPAA transport controls."

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = local.common_tags
}

resource "aws_db_instance" "postgres" {
  identifier                            = "${local.name_prefix}-postgres"
  engine                                = "postgres"
  engine_version                        = var.db_engine_version
  instance_class                        = var.db_instance_class
  allocated_storage                     = var.db_allocated_storage
  max_allocated_storage                 = var.db_max_allocated_storage
  storage_type                          = "gp3"
  storage_encrypted                     = true
  kms_key_id                            = aws_kms_key.hipaa.arn
  username                              = var.db_username
  password                              = random_password.db.result
  db_name                               = var.db_name
  port                                  = var.db_port
  multi_az                              = var.db_multi_az
  publicly_accessible                   = false
  deletion_protection                   = var.production_safeguards
  backup_retention_period               = 35
  delete_automated_backups              = false
  copy_tags_to_snapshot                 = true
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.hipaa.arn
  performance_insights_retention_period = 7
  auto_minor_version_upgrade            = true
  iam_database_authentication_enabled   = true
  apply_immediately                     = false
  backup_window                         = "03:00-05:00"
  maintenance_window                    = "sun:06:00-sun:07:00"
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  parameter_group_name                  = aws_db_parameter_group.postgres.name
  vpc_security_group_ids                = [aws_security_group.db.id]
  skip_final_snapshot                   = !var.production_safeguards
  final_snapshot_identifier             = var.production_safeguards ? "${local.name_prefix}-final-${random_string.snapshot_suffix.result}" : null

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-postgres"
    },
  )
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode(
    {
      engine   = "postgres"
      host     = aws_db_instance.postgres.address
      port     = var.db_port
      dbname   = var.db_name
      username = var.db_username
      password = random_password.db.result
      sslmode  = "require"
    }
  )
}
