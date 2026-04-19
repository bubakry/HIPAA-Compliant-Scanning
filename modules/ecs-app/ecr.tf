resource "aws_ecr_repository" "app" {
  name                 = local.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = !var.production_safeguards

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecr"
    },
  )
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode(
    {
      rules = [
        {
          rulePriority = 1
          description  = "Keep the last 30 versioned images."
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["sha-", "release-", "main-"]
            countType     = "imageCountMoreThan"
            countNumber   = 30
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Expire untagged bootstrap images after 7 days."
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = 7
          }
          action = {
            type = "expire"
          }
        },
      ]
    }
  )
}
