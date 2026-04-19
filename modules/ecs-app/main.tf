data "aws_caller_identity" "current" {}

locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  service_enabled     = var.enable_service && var.container_image != null && var.acm_certificate_arn != null
  sanitized_project   = replace(lower(var.project_name), "_", "-")
  ecr_repository_name = "${local.sanitized_project}/${var.environment}/fastapi"
  common_tags = merge(
    {
      Module     = "ecs-app"
      Compliance = "HIPAA"
    },
    var.tags,
  )
}
