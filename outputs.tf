output "vpc_id" {
  description = "ID of the HIPAA-aligned VPC."
  value       = module.hipaa_infra.vpc_id
}

output "cloudtrail_bucket_name" {
  description = "Encrypted S3 bucket that stores CloudTrail logs."
  value       = module.hipaa_infra.cloudtrail_bucket_name
}

output "app_data_bucket_name" {
  description = "Encrypted S3 bucket for regulated application data and ALB access logs."
  value       = module.hipaa_infra.app_data_bucket_name
}

output "load_balancer_logs_bucket_name" {
  description = "S3 bucket for ALB access logs using the only encryption mode AWS ALB supports."
  value       = module.hipaa_infra.load_balancer_logs_bucket_name
}

output "db_endpoint" {
  description = "Private PostgreSQL endpoint."
  value       = module.hipaa_infra.db_endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN that stores the database credentials."
  value       = module.hipaa_infra.db_secret_arn
  sensitive   = true
}

output "ecr_repository_url" {
  description = "Private ECR repository URL for the FastAPI image."
  value       = module.ecs_app.ecr_repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name when the service is enabled."
  value       = module.ecs_app.alb_dns_name
}

output "github_actions_plan_role_arn" {
  description = "OIDC role ARN for read-only Terraform plan workflows."
  value       = module.hipaa_infra.github_actions_plan_role_arn
}

output "github_actions_apply_role_arn" {
  description = "OIDC role ARN for Terraform apply and ECS deployment workflows."
  value       = module.hipaa_infra.github_actions_apply_role_arn
}
