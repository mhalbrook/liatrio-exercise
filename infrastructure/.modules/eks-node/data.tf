################################################################################
# AWS Inputs
################################################################################
data "aws_caller_identity" "account" {
  provider = aws.account
}

data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

data "aws_region" "region" {
  provider = aws.account
}
