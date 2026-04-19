resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.hipaa.arn

  tags = local.common_tags
}

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudtrail_delivery" {
  name               = "${local.name_prefix}-cloudtrail-delivery"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cloudtrail_delivery" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_delivery" {
  name   = "${local.name_prefix}-cloudtrail-delivery"
  role   = aws_iam_role.cloudtrail_delivery.id
  policy = data.aws_iam_policy_document.cloudtrail_delivery.json
}

resource "aws_cloudtrail" "this" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.hipaa.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_delivery.arn

  advanced_event_selector {
    name = "S3ObjectDataEvents"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field       = "resources.ARN"
      starts_with = ["${aws_s3_bucket.app_data.arn}/"]
    }
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_cloudwatch_log_group.cloudtrail,
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-trail"
    },
  )
}
