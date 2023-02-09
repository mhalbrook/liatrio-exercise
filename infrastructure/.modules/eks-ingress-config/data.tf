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

data "aws_eks_cluster" "cluster" {
  provider = aws.account
  name     = var.cluster_name
}

data "tls_certificate" "cluster" {
  provider = tls
  url      = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
