output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs."
  value       = [for subnet in aws_subnet.private_app : subnet.id]
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs."
  value       = [for subnet in aws_subnet.private_db : subnet.id]
}

output "kms_key_arn" {
  description = "KMS key ARN."
  value       = aws_kms_key.hipaa.arn
}

output "cloudtrail_bucket_name" {
  description = "CloudTrail bucket name."
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "app_data_bucket_name" {
  description = "Application data bucket name."
  value       = aws_s3_bucket.app_data.bucket
}

output "app_data_bucket_arn" {
  description = "Application data bucket ARN."
  value       = aws_s3_bucket.app_data.arn
}

output "load_balancer_logs_bucket_name" {
  description = "ALB access log bucket name."
  value       = aws_s3_bucket.load_balancer_logs.bucket
}

output "db_endpoint" {
  description = "Private database endpoint."
  value       = aws_db_instance.postgres.address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for the database credentials."
  value       = aws_secretsmanager_secret.db.arn
}

output "db_security_group_id" {
  description = "Database security group ID."
  value       = aws_security_group.db.id
}

output "github_actions_plan_role_arn" {
  description = "Read-only OIDC role ARN."
  value       = aws_iam_role.github_plan.arn
}

output "github_actions_apply_role_arn" {
  description = "Deployment OIDC role ARN."
  value       = aws_iam_role.github_apply.arn
}
