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

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the deployment."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDRs."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "Private database subnet CIDRs."
  type        = list(string)
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "db_username" {
  description = "Database admin username."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS allocated storage."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "RDS max allocated storage."
  type        = number
}

variable "db_multi_az" {
  description = "Whether to deploy the database in Multi-AZ mode."
  type        = bool
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format."
  type        = string
}

variable "github_plan_oidc_subjects" {
  description = "GitHub OIDC subjects trusted by the plan role."
  type        = list(string)
}

variable "github_apply_oidc_subjects" {
  description = "GitHub OIDC subjects trusted by the apply role."
  type        = list(string)
}

variable "production_safeguards" {
  description = "When true, enforces destruction protections on RDS, S3, KMS, and Secrets Manager. Set false to allow a clean terraform destroy."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
