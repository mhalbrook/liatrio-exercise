################################################################################
# Locals
################################################################################
##########################################################
# Global Locals
##########################################################
locals {
  account_name    = var.project == null ? data.aws_iam_account_alias.account_alias.account_alias : var.project                                               # allow 'project' variable to overwrite account_name, otherwise set dynamically
  full_table_name = join("-", distinct(split("-", format("%s-%s-%s-%s", data.aws_region.region.name, local.account_name, var.environment, var.table_name)))) # Set the table name in accordance with standard naming schema
}

##########################################################
# DynamoDB Table Locals
##########################################################
locals {
  local_secondary_indices  = { for v, v in var.local_secondary_index : v.range_key => v.range_key_type }                                                                                     # build map of secondary indices
  global_secondary_indices = merge({ for v, v in var.global_secondary_index : v.range_key => v.range_key_type }, { for v, v in var.global_secondary_index : v.hash_key => v.hash_key_type }) # build map of global indices
}

##########################################################
# IAM Role Locals
##########################################################
locals {
  standardized_accounts_read_only = [for v in var.trusted_entities_read_only : length(regexall("[:][0-9]{12}[:]", v)) == 0 && length(regexall("[0-9]{12}", v)) > 0 ? format("arn:aws:iam::%s:root", v) : v]  # check if a list of ARNs or Account IDs are provided. If Account IDs, then format into ARNs
  standardized_accounts_write     = [for v in var.trusted_entities_write : length(regexall("[:][0-9]{12}[:]", v)) == 0 && length(regexall("[0-9]{12}", v)) > 0 ? format("arn:aws:iam::%s:root", v) : v]      # check if a list of ARNs or Account IDs are provided. If Account IDs, then format into ARNs
  trusted_entities_read_only      = [for v in local.standardized_accounts_read_only : length(regexall("[0-9]{12}", v)) == 0 ? format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.account.id, v) : v] # Check if a list of IAM Role Names or Account IDs are provided. If IAM Roles, then format into ARNs
  trusted_entities_write          = [for v in local.standardized_accounts_write : length(regexall("[0-9]{12}", v)) == 0 ? format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.account.id, v) : v]     # Check if a list of IAM Role Names or Account IDs are provided. If IAM Roles, then format into ARNs
  read_only                       = length(local.trusted_entities_read_only) > 0 ? local.configuration_read_only : {}                                                                                        # if a list of Accounts or Roles are provided, set the configuration for Read access.
  write                           = length(local.trusted_entities_write) > 0 ? local.configuration_write : {}                                                                                                # if a list of Accounts or Roles are provided, set the configuration for Write access.
  permissions                     = merge(local.read_only, local.write)                                                                                                                                      # merge the Read and Write permission configurations to form a single map with the confgurations that are to be provisioned

  configuration_read_only = { # set a map of Accounts and/or IAM Roles & the permissions required to Read the DynamoDB Table
    read_only = {
      trusted_roles         = local.trusted_entities_read_only
      allowed_table_actions = ["dynamodb:ListTables", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:Scan"]
      allowed_kms_actions   = ["kms:Decrypt"]
    }
  }

  configuration_write = { # set a map of Accounts and/or IAM Roles & the permissions required to Write to the DynamoDB Table
    write = {
      trusted_roles         = local.trusted_entities_write
      allowed_table_actions = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:UpdateTable", "dynamodb:ListTables", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:Scan", "dynamodb:DeleteItem"]
      allowed_kms_actions   = ["kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey"]
    }
  }
}


################################################################################
# DynamoDB Table
################################################################################
resource "aws_dynamodb_table" "table" {
  provider         = aws.account
  name             = local.full_table_name
  billing_mode     = upper(var.billing_mode)
  hash_key         = element(keys(var.hash_key), 0)
  range_key        = length(var.range_key) > 0 ? element(keys(var.range_key), 0) : null
  write_capacity   = upper(var.billing_mode) == "PROVISIONED" ? var.write_capacity : 0
  read_capacity    = upper(var.billing_mode) == "PROVISIONED" ? var.read_capacity : 0
  stream_enabled   = true
  stream_view_type = upper(var.stream_view_type)

  dynamic "attribute" {
    for_each = merge(var.hash_key, var.range_key, local.local_secondary_indices, local.global_secondary_indices)
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_index
    content {
      name               = local_secondary_index.key
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type == null ? "ALL" : local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.projection_type == "INCLUDE" ? local_secondary_index.value.non_key_attributes : null
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_index
    content {
      name               = global_secondary_index.key
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type == null ? "ALL" : global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.projection_type == "INCLUDE" ? global_secondary_index.value.non_key_attributes : null
      write_capacity     = upper(var.billing_mode) == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
      read_capacity      = upper(var.billing_mode) == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
    }
  }

  dynamic "ttl" {
    for_each = var.enable_ttl == true ? [1] : []
    content {
      enabled        = var.enable_ttl
      attribute_name = var.ttl_attribute_name
    }
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment
      "data classification" = var.data_classification
    }
  )
}


################################################################################
# Identity & Access Management
################################################################################
##########################################################
# Read-only and Write Roles
##########################################################
resource "aws_iam_role" "role" {
  provider           = aws.account
  for_each           = local.permissions
  name               = format("%s-%s", local.full_table_name, replace(each.key, "_", "-"))
  description        = format("Role for %s access to %s DynamoDB table", replace(each.key, "_", "-"), local.full_table_name)
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

data "aws_iam_policy_document" "assume" {
  for_each = local.permissions
  statement {
    sid     = "OrgTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = each.value.trusted_roles
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = ["o-23xm3aw09v"]
    }
  }
}

##########################################################
# Read-only and Write Policies
##########################################################
resource "aws_iam_policy" "policy" {
  provider    = aws.account
  for_each    = local.permissions
  name        = format("%s-%s", local.full_table_name, replace(each.key, "_", "-"))
  description = format("Policy providing %s access to %s DynamoDB table", replace(each.key, "_", "-"), local.full_table_name)
  policy      = data.aws_iam_policy_document.policy[each.key].json
}

data "aws_iam_policy_document" "policy" {
  for_each = local.permissions
  statement {
    sid       = "TableAccess"
    effect    = "Allow"
    actions   = each.value.allowed_table_actions
    resources = [aws_dynamodb_table.table.arn, format("%s/index/%s", aws_dynamodb_table.table.arn, aws_dynamodb_table.table.hash_key)]
  }

  statement {
    sid       = "AllowKMS"
    effect    = "Allow"
    actions   = each.value.allowed_kms_actions
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy_attachment" "policy" {
  provider   = aws.account
  for_each   = local.permissions
  role       = aws_iam_role.role[each.key].name
  policy_arn = aws_iam_policy.policy[each.key].arn
}
