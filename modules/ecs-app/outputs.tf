output "ecr_repository_name" {
  description = "ECR repository name."
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name when enabled."
  value       = local.service_enabled ? aws_ecs_service.app[0].name : null
}

output "alb_dns_name" {
  description = "ALB DNS name when enabled."
  value       = local.service_enabled ? aws_lb.app[0].dns_name : null
}

output "alb_zone_id" {
  description = "ALB hosted zone ID when enabled."
  value       = local.service_enabled ? aws_lb.app[0].zone_id : null
}
