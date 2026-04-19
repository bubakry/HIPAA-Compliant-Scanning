variable "project_name" {
  description = "Project naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that hosts the service."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used to scope internal egress."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets used by the ALB."
  type        = list(string)
}

variable "private_app_subnet_ids" {
  description = "Private application subnets used by ECS."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN used for logs, ECR encryption, and ECS exec."
  type        = string
}

variable "db_security_group_id" {
  description = "Database security group ID."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN that stores database credentials."
  type        = string
}

variable "db_endpoint" {
  description = "Private database endpoint."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "app_data_bucket_name" {
  description = "Encrypted S3 bucket used by the application."
  type        = string
}

variable "app_data_bucket_arn" {
  description = "Encrypted S3 bucket ARN used by the application."
  type        = string
}

variable "alb_logs_bucket_name" {
  description = "S3 bucket dedicated to ALB access logs."
  type        = string
}

variable "allowed_alb_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB over HTTPS."
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener."
  type        = string
  default     = null
  nullable    = true
}

variable "application_domain_name" {
  description = "Optional Route53 hostname for the service."
  type        = string
  default     = null
  nullable    = true
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID."
  type        = string
  default     = null
  nullable    = true
}

variable "container_image" {
  description = "Container image URI."
  type        = string
  default     = null
  nullable    = true
}

variable "container_port" {
  description = "Application container port."
  type        = number
}

variable "desired_count" {
  description = "Desired number of ECS tasks."
  type        = number
}

variable "cpu" {
  description = "Fargate CPU units."
  type        = number
}

variable "memory" {
  description = "Fargate memory in MiB."
  type        = number
}

variable "enable_service" {
  description = "Whether to create the ECS service and ALB."
  type        = bool
}

variable "production_safeguards" {
  description = "When true, enforces destruction protections on the ALB and ECR repo. Set false to allow a clean terraform destroy."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
