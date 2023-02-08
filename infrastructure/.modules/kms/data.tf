################################################################################
# AWS Account inputs
################################################################################
data "aws_caller_identity" "current" {
  provider = aws.account
}

data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

#############################################################
# Primary Region
#############################################################
data "aws_region" "primary" {
  provider = aws.account
}

#############################################################
# Secondary Region
#############################################################
data "aws_region" "secondary" {
  provider = aws.secondary
}

#############################################################
# Secondary Region
#############################################################
data "aws_region" "tertiary" {
  provider = aws.tertiary
}
