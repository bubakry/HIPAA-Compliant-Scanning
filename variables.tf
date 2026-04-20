variable "project_name" {
  description = "Project name used as the resource naming prefix."
  type        = string
  default     = "hipaa-compliant-pipeline"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID that owns the deployment. Override in terraform.tfvars."
  type        = string
  default     = "000000000000"

  validation {
    condition     = can(regex("^\\d{12}$", var.account_id))
    error_message = "account_id must be a 12 digit AWS account ID."
  }
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format."
  type        = string
  default     = "your-org/HIPAA-Compliant-Scanning"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+\\/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo format."
  }
}

variable "github_main_branch" {
  description = "Primary branch trusted for deployment workflows."
  type        = string
  default     = "main"
}

variable "github_plan_oidc_subjects" {
  description = "Optional custom OIDC subjects that can assume the GitHub plan role."
  type        = list(string)
  default     = []
}

variable "github_apply_oidc_subjects" {
  description = "Optional custom OIDC subjects that can assume the GitHub apply role."
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "Availability zones used by the VPC."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets that host the ALB."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets that host ECS tasks and VPC endpoints."
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets."
  type        = list(string)
  default     = ["10.42.20.0/24", "10.42.21.0/24"]
}

variable "allowed_alb_ingress_cidrs" {
  description = "CIDRs allowed to reach the public ALB. Replace 0.0.0.0/0 with approved client networks in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "hipaadb"
}

variable "db_username" {
  description = "Database administrator username."
  type        = string
  default     = "hipaa_admin"
}

variable "db_port" {
  description = "RDS PostgreSQL listener port."
  type        = number
  default     = 5432
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.small"
}

variable "db_allocated_storage" {
  description = "Initial RDS allocated storage in GiB."
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaled RDS storage in GiB."
  type        = number
  default     = 200
}

variable "db_multi_az" {
  description = "Whether the RDS instance is deployed in Multi-AZ mode."
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN used by the internet-facing ALB HTTPS listener."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = !var.enable_service || var.acm_certificate_arn != null
    error_message = "Set acm_certificate_arn when enable_service is true so HTTPS is enforced."
  }
}

variable "application_domain_name" {
  description = "Optional DNS name to map to the ALB."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      (var.application_domain_name == null && var.route53_zone_id == null) ||
      (var.application_domain_name != null && var.route53_zone_id != null)
    )
    error_message = "application_domain_name and route53_zone_id must either both be set or both be null."
  }
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID for the application domain."
  type        = string
  default     = null
  nullable    = true
}

variable "container_image" {
  description = "Container image URI for the FastAPI workload."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = !var.enable_service || var.container_image != null
    error_message = "Set container_image when enable_service is true."
  }
}

variable "container_port" {
  description = "Container port exposed by the FastAPI service."
  type        = number
  default     = 8080
}

variable "ecs_desired_count" {
  description = "Desired task count for the ECS service."
  type        = number
  default     = 2
}

variable "ecs_cpu" {
  description = "Fargate CPU units for the task definition."
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Fargate memory in MiB for the task definition."
  type        = number
  default     = 1024
}

variable "enable_service" {
  description = "Whether to create the ECS service, ALB, and task definition. Keep false during the first bootstrap apply until an image is pushed."
  type        = bool
  default     = false
}

variable "production_safeguards" {
  description = "Enables destruction protections on RDS, S3, KMS, Secrets Manager, ALB, and ECR. Set to false to allow a clean terraform destroy."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Optional additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
