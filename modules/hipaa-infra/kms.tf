data "aws_iam_policy_document" "kms" {
  statement {
    sid = "AllowRootAccountAdministration"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "AllowCloudWatchLogs"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowCloudTrail"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:*:${var.account_id}:trail/*"]
    }
  }
}

resource "aws_kms_key" "hipaa" {
  description             = "Customer managed KMS key for HIPAA-aligned logs, data stores, and secrets."
  enable_key_rotation     = true
  deletion_window_in_days = var.production_safeguards ? 30 : 7
  policy                  = data.aws_iam_policy_document.kms.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-kms"
    },
  )
}

resource "aws_kms_alias" "hipaa" {
  name          = "alias/${local.name_prefix}-hipaa"
  target_key_id = aws_kms_key.hipaa.key_id
}
