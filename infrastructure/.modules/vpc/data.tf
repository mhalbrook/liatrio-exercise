################################################################################
# AWS Account Inputs
################################################################################
#############################################################
# Global Inputs
#############################################################
data "aws_caller_identity" "account" {
  provider = aws.account
}
data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

data "aws_region" "region" {
  provider = aws.account
}

data "aws_availability_zones" "available" {
  provider = aws.account
}

#############################################################
# KMS Inputs
#############################################################
data "aws_kms_key" "logs" { # used to encrypt VPC Flow Logs
  provider = aws.account
  count    = var.enable_flow_logs == true ? 1 : 0
  key_id   = format("alias/%s-core-logs", data.aws_region.region.name)
}
