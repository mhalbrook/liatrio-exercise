################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  account_name     = var.project == null ? data.aws_iam_account_alias.account_alias.account_alias : var.project                                                 # allow 'project' variable to overwrite account_name, otherwise set dynamically
  bucket_name      = var.is_logging_bucket == false ? var.bucket_name : "logs"                                                                                  # if the bucket is a logging bucket, overwrite the bucket name to 'logs'
  full_bucket_name = var.suppress_region == false ? format("%s-%s-%s", data.aws_region.primary.name, local.account_name, local.bucket_name) : local.bucket_name # set bucket name to align to standard schema
}

#############################################################
# Bucket Policy Locals
#############################################################
locals {
  acl                = var.is_logging_bucket == true ? "log-delivery-write" : "private"
  cors               = var.allowed_headers != null || var.allowed_methods != null || var.allowed_origins != null || var.expose_headers != null ? true : false # if any CORS variable is not null, set CORS to 'true'
  enable_access_logs = var.is_logging_bucket == true || var.enable_access_logs == false ? false : true
  sync_buckets       = var.replication_region_count > 0 ? var.sync_buckets : false # ensure sync is off when replication is off
  alb_service_accounts = merge(                                                    # use merge to ensure the local does not attempt to duplicate keys (i.e. same region is provided twice from root)
    { (data.aws_elb_service_account.primary.region) = data.aws_elb_service_account.primary.arn },
    { (data.aws_elb_service_account.secondary.region) = data.aws_elb_service_account.secondary.arn },
    { (data.aws_elb_service_account.tertiary.region) = data.aws_elb_service_account.tertiary.arn }
  )
  logging_buckets = local.enable_access_logs == true ? merge( # use merge to ensure the local does not attempt to duplicate keys (i.e. same region is provided twice from root)
    { (data.aws_s3_bucket.account_logging_bucket_primary[0].region) = data.aws_s3_bucket.account_logging_bucket_primary[0] },
    { (data.aws_s3_bucket.account_logging_bucket_secondary[0].region) = data.aws_s3_bucket.account_logging_bucket_secondary[0] },
    { (data.aws_s3_bucket.account_logging_bucket_tertiary[0].region) = data.aws_s3_bucket.account_logging_bucket_tertiary[0] }
  ) : {}
}

locals {
  buckets = {
    for k, v in merge( # Create a map with an argument for each region, depending on how many regiosn are required for replication
      { primary = data.aws_region.primary.name },
      var.replication_region_count > 0 ? { secondary = data.aws_region.secondary.name } : {},
      var.replication_region_count > 1 ? { tertiary = data.aws_region.tertiary.name } : {}
    ) :
    k => {                                                                                                                                  # create a map for each bucket that needs creation and the corresponding arguments
      name                = var.suppress_region == false ? format("%s-%s-%s", v, local.account_name, local.bucket_name) : local.bucket_name # set bucket name to align to standard schema
      region              = v
      arn                 = format("arn:aws:s3:::%s", var.suppress_region == false ? format("%s-%s-%s", v, local.account_name, local.bucket_name) : local.bucket_name)
      kms_key_arn         = one([for x in var.kms_key_arns : x if contains(split(":", x), v)]) # if the kms key arn contains the region name
      alb_service_account = local.alb_service_accounts[v]
      objects             = format("arn:aws:s3:::%s/*", var.suppress_region == false ? format("%s-%s-%s", v, local.account_name, local.bucket_name) : local.bucket_name)
      logging_bucket      = try(local.logging_buckets[v], null)
    }
  }
}


#############################################################
# Lifecycle Rule Locals
#############################################################
locals {
  default_lifecycle = length(var.lifecycle_rules) > 0 ? {} : local.standard_lifecycle                 # if custom lifecycle is provided, do not set a default lifecycle, otherwise set default to standard lifecycle: allows the lifecycle local to perform a reliable condition comparison
  lifecycles        = length(var.lifecycle_rules) > 0 ? var.lifecycle_rules : local.default_lifecycle # Set to custom lifeycle if provided, otherwise set to default lifecycle
  ######
  standard_lifecycle = { # Set the standard lifecycle 
    default-lifecycle = {
      prefix                        = null
      expiration                    = var.is_logging_bucket == false ? null : 14
      noncurrent_version_expiration = var.is_logging_bucket == false ? 90 : 7
      transitions = {
        1 = "INTELLIGENT_TIERING"
      }
      noncurrent_version_transitions = {}
    }
  }
}


################################################################################
# Random String - Ensure Bucket Names are Unique for Repeat Build & Destroy
################################################################################
resource "random_string" "random" {
  length  = 4
  special = false
}

################################################################################
# Bucket
################################################################################
resource "aws_s3_bucket" "primary" {
  provider      = aws.account
  for_each      = { for k, v in local.buckets : k => v if k == "primary" }
  bucket        = each.value.name
  force_destroy = var.delete_unemptied_bucket

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}


################################################################################
# Replicated Bucket
################################################################################
resource "aws_s3_bucket" "secondary" {
  provider      = aws.secondary
  for_each      = { for k, v in local.buckets : k => v if k == "secondary" }
  bucket        = each.value.name
  force_destroy = var.delete_unemptied_bucket

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}

################################################################################
# Replicated Bucket
################################################################################
resource "aws_s3_bucket" "tertiary" {
  provider      = aws.tertiary
  for_each      = { for k, v in local.buckets : k => v if k == "tertiary" }
  bucket        = each.value.name
  force_destroy = var.delete_unemptied_bucket

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}

##########################################
# Access Control List
##########################################
resource "aws_s3_bucket_acl" "primary" {
  provider = aws.account
  for_each = { for k, v in local.buckets : k => v if k == "primary" }
  bucket   = aws_s3_bucket.primary[each.key].id
  acl      = local.acl
}

resource "aws_s3_bucket_acl" "secondary" {
  provider = aws.secondary
  for_each = { for k, v in local.buckets : k => v if k == "secondary" }
  bucket   = aws_s3_bucket.secondary[each.key].id
  acl      = local.acl
}

resource "aws_s3_bucket_acl" "tertiary" {
  provider = aws.tertiary
  for_each = { for k, v in local.buckets : k => v if k == "tertiary" }
  bucket   = aws_s3_bucket.tertiary[each.key].id
  acl      = local.acl
}

##########################################
# Versioning 
##########################################
resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.account
  for_each = { for k, v in local.buckets : k => v if k == "primary" }
  bucket   = aws_s3_bucket.primary[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  for_each = { for k, v in local.buckets : k => v if k == "secondary" }
  bucket   = aws_s3_bucket.secondary[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "tertiary" {
  provider = aws.tertiary
  for_each = { for k, v in local.buckets : k => v if k == "tertiary" }
  bucket   = aws_s3_bucket.tertiary[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

##########################################
# Logging 
##########################################
resource "aws_s3_bucket_logging" "primary" {
  provider      = aws.account
  for_each      = local.enable_access_logs == true ? { for k, v in local.buckets : k => v if k == "primary" } : {}
  bucket        = aws_s3_bucket.primary[each.key].id
  target_bucket = each.value.logging_bucket["id"]
  target_prefix = format("%s/access-logs/s3/%s/", var.environment, each.value.name)
}

resource "aws_s3_bucket_logging" "secondary" {
  provider      = aws.secondary
  for_each      = local.enable_access_logs == true ? { for k, v in local.buckets : k => v if k == "secondary" } : {}
  bucket        = aws_s3_bucket.secondary[each.key].id
  target_bucket = each.value.logging_bucket["id"]
  target_prefix = format("%s/access-logs/s3/%s/", var.environment, each.value.name)
}

resource "aws_s3_bucket_logging" "tertiary" {
  provider      = aws.tertiary
  for_each      = local.enable_access_logs == true ? { for k, v in local.buckets : k => v if k == "tertiary" } : {}
  bucket        = aws_s3_bucket.tertiary[each.key].id
  target_bucket = each.value.logging_bucket["id"]
  target_prefix = format("%s/access-logs/s3/%s/", var.environment, each.value.name)
}


##########################################
# Encryption 
##########################################
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  provider = aws.account
  for_each = { for k, v in local.buckets : k => v if k == "primary" }
  bucket   = aws_s3_bucket.primary[each.key].id

  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.is_logging_bucket == true ? "AES256" : "aws:kms"
      kms_master_key_id = var.is_logging_bucket == true ? null : each.value.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secondary" {
  provider = aws.secondary
  for_each = { for k, v in local.buckets : k => v if k == "secondary" }
  bucket   = aws_s3_bucket.secondary[each.key].id

  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.is_logging_bucket == true ? "AES256" : "aws:kms"
      kms_master_key_id = var.is_logging_bucket == true ? null : each.value.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tertiary" {
  provider = aws.tertiary
  for_each = { for k, v in local.buckets : k => v if k == "tertiary" }
  bucket   = aws_s3_bucket.tertiary[each.key].id

  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.is_logging_bucket == true ? "AES256" : "aws:kms"
      kms_master_key_id = var.is_logging_bucket == true ? null : each.value.kms_key_arn
    }
  }
}


##########################################
# Lifecycle Rules 
##########################################
resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  provider = aws.account
  for_each = { for k, v in local.buckets : k => v if k == "primary" }
  bucket   = aws_s3_bucket.primary[each.key].id

  dynamic "rule" {
    for_each = local.lifecycles
    content {
      id     = rule.key
      status = "Enabled"
      prefix = rule.value.prefix

      abort_incomplete_multipart_upload {
        days_after_initiation = 2
      }

      dynamic "filter" {
        for_each = rule.value.prefix != null ? ["prefix"] : []
        content {
          prefix = rule.value.prefix
        }
      }

      expiration {
        days                         = rule.value.expiration != null ? rule.value.expiration : null
        expired_object_delete_marker = rule.value.expiration != null ? false : true
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? ["expiration"] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.key
          storage_class = transition.value
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.key
          storage_class   = noncurrent_version_transition.value
        }
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "secondary" {
  provider = aws.secondary
  for_each = { for k, v in local.buckets : k => v if k == "secondary" }
  bucket   = aws_s3_bucket.secondary[each.key].id

  dynamic "rule" {
    for_each = local.lifecycles
    content {
      id     = rule.key
      status = "Enabled"
      prefix = rule.value.prefix

      abort_incomplete_multipart_upload {
        days_after_initiation = 2
      }

      dynamic "filter" {
        for_each = rule.value.prefix != null ? ["prefix"] : []
        content {
          prefix = rule.value.prefix
        }
      }

      expiration {
        days                         = rule.value.expiration != null ? rule.value.expiration : null
        expired_object_delete_marker = rule.value.expiration != null ? false : true
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? ["expiration"] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.key
          storage_class = transition.value
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.key
          storage_class   = noncurrent_version_transition.value
        }
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tertiary" {
  provider = aws.tertiary
  for_each = { for k, v in local.buckets : k => v if k == "tertiary" }
  bucket   = aws_s3_bucket.tertiary[each.key].id

  dynamic "rule" {
    for_each = local.lifecycles
    content {
      id     = rule.key
      status = "Enabled"
      prefix = rule.value.prefix

      abort_incomplete_multipart_upload {
        days_after_initiation = 2
      }

      dynamic "filter" {
        for_each = rule.value.prefix != null ? ["prefix"] : []
        content {
          prefix = rule.value.prefix
        }
      }

      expiration {
        days                         = rule.value.expiration != null ? rule.value.expiration : null
        expired_object_delete_marker = rule.value.expiration != null ? false : true
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? ["expiration"] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.key
          storage_class = transition.value
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.key
          storage_class   = noncurrent_version_transition.value
        }
      }
    }
  }
}

##########################################
# Replication 
##########################################
resource "null_resource" "bucket_creation_check" { # checks to ensure all relevant buckets are created before attempting to apply replication configurations
  triggers = {
    for k, v in merge(
      aws_s3_bucket.primary,
      var.replication_region_count > 0 ? aws_s3_bucket.secondary : {},
      var.replication_region_count > 1 ? aws_s3_bucket.tertiary : {}
    ) : k => v.id
  }
}


resource "aws_s3_bucket_replication_configuration" "primary" {
  provider = aws.account
  for_each = var.replication_region_count > 0 ? { for k, v in local.buckets : k => v if k == "primary" } : {} # not equal primary to target destinations
  bucket   = aws_s3_bucket.primary[each.key].id
  role     = aws_iam_role.replication[0].arn

  dynamic "rule" {
    for_each = { for k, v in local.buckets : k => v if k != "primary" }
    content {
      id       = format("%s-replication", rule.value.name)
      status   = "Enabled"
      priority = index(keys(local.buckets), rule.key)
      filter {} # required for RTC
      source_selection_criteria {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }

      delete_marker_replication {
        status = "Disabled"
      }

      destination {
        bucket = rule.value.arn
        encryption_configuration {
          replica_kms_key_id = rule.value.kms_key_arn
        }

        dynamic "replication_time" {
          for_each = var.enable_rtc ? ["rtc"] : []
          content {
            status = "Enabled"
            time {
              minutes = 15
            }
          }
        }

        dynamic "metrics" {
          for_each = var.enable_rtc ? ["rtc"] : []
          content {
            status = "Enabled"
            event_threshold {
              minutes = 15
            }
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.primary, null_resource.bucket_creation_check]
}

resource "aws_s3_bucket_replication_configuration" "secondary" {
  provider = aws.secondary
  for_each = local.sync_buckets == true ? { for k, v in local.buckets : k => v if k == "secondary" } : {}
  bucket   = aws_s3_bucket.secondary[each.key].id
  role     = aws_iam_role.replication[0].arn

  dynamic "rule" {
    for_each = { for k, v in local.buckets : k => v if k != "secondary" }
    content {
      id       = format("%s-replication", rule.value.name)
      status   = "Enabled"
      priority = 0
      filter {} # required for RTC

      source_selection_criteria {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }

      delete_marker_replication {
        status = "Disabled"
      }

      destination {
        bucket = rule.value.arn
        encryption_configuration {
          replica_kms_key_id = rule.value.kms_key_arn
        }

        dynamic "replication_time" {
          for_each = var.enable_rtc ? ["rtc"] : []
          content {
            status = "Enabled"
            time {
              minutes = 15
            }
          }
        }

        dynamic "metrics" {
          for_each = var.enable_rtc ? ["rtc"] : []
          content {
            status = "Enabled"
            event_threshold {
              minutes = 15
            }
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.secondary, null_resource.bucket_creation_check]
}

resource "aws_s3_bucket_replication_configuration" "tertiary" {
  provider = aws.tertiary
  for_each = local.sync_buckets == true ? { for k, v in local.buckets : k => v if k == "tertiary" } : {}
  bucket   = aws_s3_bucket.tertiary[each.key].id
  role     = aws_iam_role.replication[0].arn

  dynamic "rule" {
    for_each = { for k, v in local.buckets : k => v if k != "tertiary" }
    content {
      id       = format("%s-replication", rule.value.name)
      status   = "Enabled"
      priority = 0
      filter {} # required for RTC
      source_selection_criteria {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }

      delete_marker_replication {
        status = "Disabled"
      }

      destination {
        bucket = rule.value.arn
        encryption_configuration {
          replica_kms_key_id = rule.value.kms_key_arn
        }

        dynamic "replication_time" {
          for_each = var.enable_rtc ? ["rtc"] : []
          content {
            status = "Enabled"
            time {
              minutes = 15
            }
          }
        }

        dynamic "metrics" {
          for_each = var.enable_rtc ? ["rtc"] : []
          content {
            status = "Enabled"
            event_threshold {
              minutes = 15
            }
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.tertiary, null_resource.bucket_creation_check]
}

##########################################
# Bucket Policy
##########################################
resource "aws_s3_bucket_policy" "primary" {
  provider = aws.account
  for_each = var.default_bucket_policy == true ? { for k, v in local.buckets : k => v if k == "primary" } : {}
  bucket   = aws_s3_bucket.primary[each.key].id
  policy   = var.is_logging_bucket ? data.aws_iam_policy_document.logging_bucket_policy[each.key].json : data.aws_iam_policy_document.bucket_policy[each.key].json
}

resource "aws_s3_bucket_policy" "secondary" {
  provider = aws.secondary
  for_each = var.default_bucket_policy == true ? { for k, v in local.buckets : k => v if k == "secondary" } : {}
  bucket   = aws_s3_bucket.secondary[each.key].id
  policy   = var.is_logging_bucket ? data.aws_iam_policy_document.logging_bucket_policy[each.key].json : data.aws_iam_policy_document.bucket_policy[each.key].json
}

resource "aws_s3_bucket_policy" "tertiary" {
  provider = aws.tertiary
  for_each = var.default_bucket_policy == true ? { for k, v in local.buckets : k => v if k == "tertiary" } : {}
  bucket   = aws_s3_bucket.tertiary[each.key].id
  policy   = var.is_logging_bucket ? data.aws_iam_policy_document.logging_bucket_policy[each.key].json : data.aws_iam_policy_document.bucket_policy[each.key].json
}

#############################################################
# Public Access Block
#############################################################
resource "aws_s3_bucket_public_access_block" "primary" {
  provider                = aws.account
  for_each                = { for k, v in local.buckets : k => v if k == "primary" }
  bucket                  = aws_s3_bucket.primary[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "secondary" {
  provider                = aws.secondary
  for_each                = { for k, v in local.buckets : k => v if k == "secondary" }
  bucket                  = aws_s3_bucket.secondary[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "tertiary" {
  provider                = aws.tertiary
  for_each                = { for k, v in local.buckets : k => v if k == "tertiary" }
  bucket                  = aws_s3_bucket.tertiary[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##########################################
# CORS 
##########################################
resource "aws_s3_bucket_cors_configuration" "primary" {
  provider = aws.account
  for_each = local.cors == true ? { for k, v in local.buckets : k => v if k == "primary" } : {}
  bucket   = aws_s3_bucket.primary[each.key].id
  cors_rule {
    allowed_headers = var.allowed_headers
    allowed_methods = var.allowed_methods
    allowed_origins = var.allowed_origins
    expose_headers  = var.expose_headers
    max_age_seconds = var.max_age_seconds
  }
}

resource "aws_s3_bucket_cors_configuration" "secondary" {
  provider = aws.secondary
  for_each = local.cors == true ? { for k, v in local.buckets : k => v if k == "secondary" } : {}
  bucket   = aws_s3_bucket.secondary[each.key].id
  cors_rule {
    allowed_headers = var.allowed_headers
    allowed_methods = var.allowed_methods
    allowed_origins = var.allowed_origins
    expose_headers  = var.expose_headers
    max_age_seconds = var.max_age_seconds
  }
}

resource "aws_s3_bucket_cors_configuration" "tertiary" {
  provider = aws.tertiary
  for_each = local.cors == true ? { for k, v in local.buckets : k => v if k == "tertiary" } : {}
  bucket   = aws_s3_bucket.tertiary[each.key].id
  cors_rule {
    allowed_headers = var.allowed_headers
    allowed_methods = var.allowed_methods
    allowed_origins = var.allowed_origins
    expose_headers  = var.expose_headers
    max_age_seconds = var.max_age_seconds
  }
}


################################################################################
# Replication IAM Role
################################################################################
resource "aws_iam_role" "replication" {
  provider           = aws.account
  count              = var.replication_region_count > 0 ? 1 : 0
  name               = format("%s-%s-s3-replication", local.account_name, var.bucket_name)
  description        = format("role for replicating S3 objects between %s buckets", local.bucket_name)
  assume_role_policy = data.aws_iam_policy_document.assume_s3[0].json

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}

data "aws_iam_policy_document" "assume_s3" {
  provider = aws.account
  count    = var.replication_region_count > 0 ? 1 : 0
  statement {
    sid     = "S3Trust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "replication" {
  provider = aws.account
  count    = var.replication_region_count > 0 ? 1 : 0
  statement {
    sid       = "GetBucketInfo"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetReplicationConfiguration"]
    resources = [for k, v in local.buckets : v.arn]
  }
  statement {
    sid       = "AllowReplication"
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:GetObjectVersionTagging", "s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging", "s3:GetObjectRetention", "s3:GetObjectLegalHold"]
    resources = flatten([for k, v in local.buckets : [v.arn, v.objects]])
  }
  statement {
    sid       = "AllowKMS"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [for k, v in local.buckets : v.kms_key_arn]
  }
}

resource "aws_iam_policy" "replication" {
  provider    = aws.account
  count       = var.replication_region_count > 0 ? 1 : 0
  name        = format("%s-replication", var.bucket_name)
  description = format("policy allowing S3 replication between %s buckets", var.bucket_name)
  policy      = data.aws_iam_policy_document.replication[0].json
}

resource "aws_iam_role_policy_attachment" "replication" {
  provider   = aws.account
  count      = var.replication_region_count > 0 ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}


################################################################################
# Bucket Policies
################################################################################
#############################################################
# Default Bucket Policy
#############################################################
data "aws_iam_policy_document" "bucket_policy" {
  provider = aws.account
  for_each = local.buckets
  statement {
    sid       = "AllowSSLRequestsOnly"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [each.value.arn, each.value.objects]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

#############################################################
# Bucket Policy for logging Bucket
#############################################################
data "aws_iam_policy_document" "logging_bucket_policy" {
  provider = aws.account
  for_each = local.buckets

  statement {
    sid       = "AllowSSLRequestsOnly"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [each.value.arn, each.value.objects]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowResourceLogging"
    actions   = ["s3:PutObject"]
    resources = [each.value.objects]

    principals {
      type        = "AWS"
      identifiers = [each.value.alb_service_account]
    }
  }

  statement {
    sid       = "AWSLogDeliveryWrite"
    actions   = ["s3:PutObject"]
    resources = [each.value.objects]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com", "delivery.logs.amazonaws.com", "logging.s3.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "AWSLogDeliveryAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [each.value.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com", "delivery.logs.amazonaws.com"]
    }
  }
}


################################################################################
# CloudTrail
################################################################################
resource "aws_cloudtrail" "primary" {
  provider                      = aws.account
  for_each                      = var.enable_cloudtrail == true ? { for k, v in local.buckets : k => v if k == "primary" } : {}
  name                          = format("%s-trail", each.value.name)
  s3_bucket_name                = each.value.logging_bucket
  s3_key_prefix                 = format("cloudtrail/%s", each.value.name)
  enable_log_file_validation    = true
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = formatlist("%s/", each.value.name)
    }
  }
}

resource "aws_cloudtrail" "secondary" {
  provider                      = aws.secondary
  for_each                      = var.enable_cloudtrail == true ? { for k, v in local.buckets : k => v if k == "secondary" } : {}
  name                          = format("%s-trail", each.value.name)
  s3_bucket_name                = each.value.logging_bucket
  s3_key_prefix                 = format("cloudtrail/%s", each.value.name)
  enable_log_file_validation    = true
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = formatlist("%s/", each.value.name)
    }
  }
}

resource "aws_cloudtrail" "tertiary" {
  provider                      = aws.tertiary
  for_each                      = var.enable_cloudtrail == true ? { for k, v in local.buckets : k => v if k == "tertiary" } : {}
  name                          = format("%s-trail", each.value.name)
  s3_bucket_name                = each.value.logging_bucket
  s3_key_prefix                 = format("cloudtrail/%s", each.value.name)
  enable_log_file_validation    = true
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = formatlist("%s/", each.value.name)
    }
  }
}
