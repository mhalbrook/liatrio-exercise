################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  full_key_name = { for v in local.regions : v => format("%s-%s-%s", v, var.environment, var.suffix) }                                                      # sets key name for primary KMS Key
  regions       = slice([data.aws_region.primary.name, data.aws_region.secondary.name, data.aws_region.tertiary.name], 0, var.replication_region_count + 1) # generates a list of regions based ont he replication_region_count variable
}

#############################################################
# Key Policy Locals
#############################################################
locals {
  key_policy = var.key_policy == null ? data.aws_iam_policy_document.key_policy.json : var.key_policy # Sets custom key policy if provided, otherwise sets to default policy
}


################################################################################
# KMS Key Policies
################################################################################
#############################################################
# Default Key Policy
#############################################################
data "aws_iam_policy_document" "key_policy" {
  provider  = aws.account
  policy_id = "key-default-1"
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = formatlist("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id)
    }
  }
  dynamic "statement" {
    for_each = var.is_logging_key ? ["logging"] : []
    content {
      sid       = "AllowCloudWatchAccess"
      effect    = "Allow"
      actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEcrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = formatlist("logs.%s.amazonaws.com", local.regions)
      }
      condition {
        test     = "ArnEquals"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = [format("arn:aws:logs:*:%s:*", data.aws_caller_identity.current.id)]
      }
    }
  }
}


################################################################################
# KMS Keys
################################################################################
#############################################################
# Primary KMS Key
#############################################################
resource "aws_kms_key" "primary" {
  provider                = aws.account
  for_each                = toset([data.aws_region.primary.name]) # using for_each to maintain resource naming consistency in state file when multi-region
  description             = format("KMS key for %s", var.service)
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.key_policy

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_kms_alias" "primary" {
  provider      = aws.account
  for_each      = aws_kms_key.primary
  name          = format("alias/%s", local.full_key_name[data.aws_region.primary.name])
  target_key_id = each.value.id
}


#############################################################
# Secondary KMS Key
#############################################################
resource "aws_kms_key" "secondary" {
  provider                = aws.secondary
  for_each                = var.replication_region_count > 0 ? toset([data.aws_region.secondary.name]) : [] # use for_each to manage datatype when not created, so that dynamic outputs function properly
  description             = format("KMS key for %s", var.service)
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.key_policy

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_kms_alias" "secondary" {
  provider      = aws.secondary
  for_each      = aws_kms_key.secondary
  name          = format("alias/%s", local.full_key_name[data.aws_region.secondary.name])
  target_key_id = each.value.id
}

#############################################################
# Tertiary KMS Key
#############################################################
resource "aws_kms_key" "tertiary" {
  provider                = aws.tertiary
  for_each                = var.replication_region_count > 1 ? toset([data.aws_region.tertiary.name]) : [] # use for_each manage datatype when not created, so that dynamic outputs function properly
  description             = format("KMS key for %s", var.service)
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.key_policy

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}
resource "aws_kms_alias" "tertiary" {
  provider      = aws.tertiary
  for_each      = aws_kms_key.tertiary
  name          = format("alias/%s", local.full_key_name[data.aws_region.tertiary.name])
  target_key_id = each.value.id
}

