data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid    = "ReadRuntimeSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.db_secret_arn,
      var.kms_key_arn,
    ]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "${local.name_prefix}-ecs-execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "task" {
  statement {
    sid    = "ReadAppSecret"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.db_secret_arn,
      var.kms_key_arn,
    ]
  }

  statement {
    sid    = "ReadWriteEncryptedAppData"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [var.app_data_bucket_arn]
  }

  statement {
    sid    = "ReadWriteEncryptedObjects"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]
    resources = ["${var.app_data_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${local.name_prefix}-ecs-task"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}
