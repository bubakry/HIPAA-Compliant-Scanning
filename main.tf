locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = merge(
    {
      Project        = var.project_name
      Environment    = var.environment
      ManagedBy      = "Terraform"
      Compliance     = "HIPAA"
      Repository     = var.github_repository
      SecurityTier   = "regulated"
      DeploymentTool = "GitHub Actions"
    },
    var.tags,
  )

  github_plan_subjects = length(var.github_plan_oidc_subjects) > 0 ? var.github_plan_oidc_subjects : [
    "repo:${var.github_repository}:ref:refs/heads/${var.github_main_branch}",
    "repo:${var.github_repository}:pull_request",
  ]

  github_apply_subjects = length(var.github_apply_oidc_subjects) > 0 ? var.github_apply_oidc_subjects : [
    "repo:${var.github_repository}:ref:refs/heads/${var.github_main_branch}",
  ]
}

module "hipaa_infra" {
  source = "./modules/hipaa-infra"

  project_name               = var.project_name
  environment                = var.environment
  aws_region                 = var.aws_region
  account_id                 = var.account_id
  availability_zones         = var.availability_zones
  vpc_cidr                   = var.vpc_cidr
  public_subnet_cidrs        = var.public_subnet_cidrs
  private_app_subnet_cidrs   = var.private_app_subnet_cidrs
  private_db_subnet_cidrs    = var.private_db_subnet_cidrs
  db_name                    = var.db_name
  db_username                = var.db_username
  db_port                    = var.db_port
  db_engine_version          = var.db_engine_version
  db_instance_class          = var.db_instance_class
  db_allocated_storage       = var.db_allocated_storage
  db_max_allocated_storage   = var.db_max_allocated_storage
  db_multi_az                = var.db_multi_az
  github_repository          = var.github_repository
  github_plan_oidc_subjects  = local.github_plan_subjects
  github_apply_oidc_subjects = local.github_apply_subjects
  production_safeguards      = var.production_safeguards
  tags                       = local.tags
}

module "ecs_app" {
  source = "./modules/ecs-app"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  vpc_id                    = module.hipaa_infra.vpc_id
  vpc_cidr                  = var.vpc_cidr
  public_subnet_ids         = module.hipaa_infra.public_subnet_ids
  private_app_subnet_ids    = module.hipaa_infra.private_app_subnet_ids
  kms_key_arn               = module.hipaa_infra.kms_key_arn
  db_security_group_id      = module.hipaa_infra.db_security_group_id
  db_secret_arn             = module.hipaa_infra.db_secret_arn
  db_endpoint               = module.hipaa_infra.db_endpoint
  db_port                   = var.db_port
  db_name                   = var.db_name
  app_data_bucket_name      = module.hipaa_infra.app_data_bucket_name
  app_data_bucket_arn       = module.hipaa_infra.app_data_bucket_arn
  alb_logs_bucket_name      = module.hipaa_infra.load_balancer_logs_bucket_name
  allowed_alb_ingress_cidrs = var.allowed_alb_ingress_cidrs
  acm_certificate_arn       = var.acm_certificate_arn
  application_domain_name   = var.application_domain_name
  route53_zone_id           = var.route53_zone_id
  container_image           = var.container_image
  container_port            = var.container_port
  desired_count             = var.ecs_desired_count
  cpu                       = var.ecs_cpu
  memory                    = var.ecs_memory
  enable_service            = var.enable_service
  production_safeguards     = var.production_safeguards
  tags                      = local.tags
}
