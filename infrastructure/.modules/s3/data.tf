################################################################################
# AWS Account inputs
################################################################################
data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}


################################################################################
# Primary Region
################################################################################
data "aws_region" "primary" {
  provider = aws.account
}

data "aws_s3_bucket" "account_logging_bucket_primary" {
  provider = aws.account
  count    = local.enable_access_logs == true ? 1 : 0
  bucket   = format("%s-%s-logs", data.aws_region.primary.name, local.account_name)
}

data "aws_elb_service_account" "primary" { # accounts from which AWS delivers S3/ELB Access Logs
  provider = aws.account
  region   = data.aws_region.primary.name
}


################################################################################
# Secondary Region
################################################################################
data "aws_region" "secondary" {
  provider = aws.secondary
}

data "aws_s3_bucket" "account_logging_bucket_secondary" {
  provider = aws.secondary
  count    = local.enable_access_logs == true ? 1 : 0
  bucket   = format("%s-%s-logs", data.aws_region.secondary.name, local.account_name)
}

data "aws_elb_service_account" "secondary" {
  provider = aws.secondary
  region   = data.aws_region.secondary.name
}

################################################################################
# Tertiary Region
################################################################################
data "aws_region" "tertiary" {
  provider = aws.tertiary
}

data "aws_s3_bucket" "account_logging_bucket_tertiary" {
  provider = aws.tertiary
  count    = local.enable_access_logs == true ? 1 : 0
  bucket   = format("%s-%s-logs", data.aws_region.tertiary.name, local.account_name)
}

data "aws_elb_service_account" "tertiary" {
  provider = aws.tertiary
  region   = data.aws_region.tertiary.name
}





