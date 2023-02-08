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


################################################################################
# VPC Inputs
################################################################################
data "aws_vpc" "vpc" {
  provider = aws.account 
  id = var.vpc_id
}

data "aws_subnet" "subnet" {
  provider = aws.account
  for_each = toset(var.subnet_ids)
  id       = each.value
}

