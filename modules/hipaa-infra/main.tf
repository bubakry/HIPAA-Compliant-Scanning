data "aws_partition" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    {
      Module     = "hipaa-infra"
      Compliance = "HIPAA"
    },
    var.tags,
  )

  public_subnet_map      = zipmap(var.availability_zones, var.public_subnet_cidrs)
  private_app_subnet_map = zipmap(var.availability_zones, var.private_app_subnet_cidrs)
  private_db_subnet_map  = zipmap(var.availability_zones, var.private_db_subnet_cidrs)
  interface_endpoint_names = toset([
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "kms",
    "logs",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "sts",
  ])

  sanitized_prefix     = substr(replace(lower(local.name_prefix), "_", "-"), 0, 28)
  trail_bucket_name    = "${local.sanitized_prefix}-${var.account_id}-${random_string.suffix.result}-trail"
  app_data_bucket_name = "${local.sanitized_prefix}-${var.account_id}-${random_string.suffix.result}-data"
  lb_logs_bucket_name  = "${local.sanitized_prefix}-${var.account_id}-${random_string.suffix.result}-alb"
  plan_role_name       = "${local.name_prefix}-github-actions-plan"
  apply_role_name      = "${local.name_prefix}-github-actions-apply"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
