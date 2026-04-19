resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-github-oidc"
    },
  )
}

data "aws_iam_policy_document" "github_plan_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_plan_oidc_subjects
    }
  }
}

data "aws_iam_policy_document" "github_apply_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_apply_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = local.plan_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_plan_assume_role.json
  max_session_duration = 3600

  tags = local.common_tags
}

resource "aws_iam_role" "github_apply" {
  name                 = local.apply_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_apply_assume_role.json
  max_session_duration = 3600

  tags = local.common_tags
}

data "aws_iam_policy_document" "github_plan" {
  statement {
    sid    = "ReadOnlyPlatformServices"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "ec2:Describe*",
      "ecr:Describe*",
      "ecr:GetAuthorizationToken",
      "ecr:List*",
      "ecs:Describe*",
      "ecs:List*",
      "elasticloadbalancing:Describe*",
      "iam:Get*",
      "iam:List*",
      "kms:DescribeKey",
      "kms:List*",
      "logs:Describe*",
      "logs:GetLogEvents",
      "rds:Describe*",
      "route53:GetHostedZone",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicy",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetBucketVersioning",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecrets",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_plan" {
  name   = "${local.name_prefix}-github-plan"
  policy = data.aws_iam_policy_document.github_plan.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_plan" {
  role       = aws_iam_role.github_plan.name
  policy_arn = aws_iam_policy.github_plan.arn
}

data "aws_iam_policy_document" "github_apply" {
  statement {
    sid    = "ManagePlatformResources"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "cloudtrail:*",
      "ec2:*",
      "ecr:*",
      "ecs:*",
      "elasticloadbalancing:*",
      "iam:AttachRolePolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreateRole",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:Get*",
      "iam:List*",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagOpenIDConnectProvider",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagOpenIDConnectProvider",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "kms:CancelKeyDeletion",
      "kms:CreateAlias",
      "kms:CreateGrant",
      "kms:CreateKey",
      "kms:Decrypt",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:GetKeyPolicy",
      "kms:List*",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "logs:*",
      "rds:*",
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "s3:*",
      "secretsmanager:*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowServiceLinkedRoles"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_apply" {
  name   = "${local.name_prefix}-github-apply"
  policy = data.aws_iam_policy_document.github_apply.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_apply" {
  role       = aws_iam_role.github_apply.name
  policy_arn = aws_iam_policy.github_apply.arn
}
