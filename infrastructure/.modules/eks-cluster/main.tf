################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  account_name      = var.project == null ? data.aws_iam_account_alias.account_alias.account_alias : var.project                # allow 'project' variable to overwrite account_name, otherwise set dynamically
  full_cluster_name = format("%s-%s-%s-%s", data.aws_region.region.name, var.environment, local.account_name, var.cluster_name) # set name to align to standard schema
}

#############################################################
# Tagging Locals
#############################################################
locals {
  default_tags = {
    builtby     = "terraform"
    environment = var.environment
  }
}

#############################################################
# Network Locals
#############################################################
locals {
  subnet_cidrs = [for k, v in data.aws_subnet.subnet : v.cidr_block]
}

#############################################################
# IAM Locals
#############################################################
locals {
  amazon_managed_policies = {
    cluster = toset(["AmazonEKSClusterPolicy", "AmazonEKSVPCResourceController"])
    pods    = toset(["AmazonEKSFargatePodExecutionRolePolicy"])
  }
}


################################################################################
# Cluster
################################################################################
resource "aws_eks_cluster" "cluster" {
  provider                  = aws.account
  name                      = local.full_cluster_name
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = var.log_types
  depends_on                = [aws_iam_role_policy_attachment.amazon_managed_policies_cluster]
  tags                      = merge(var.tags, local.default_tags)

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = var.cluster_api_access == "private"
    endpoint_public_access  = var.cluster_api_access == "public"
    public_access_cidrs     = var.cluster_api_access_cidrs
  }

  dynamic "encryption_config" {
    for_each = var.kms_key_arn != null ? toset(["key"]) : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = var.kms_key_arn
      }
    }
  }
}


################################################################################
# CoreDNS
################################################################################
resource "aws_eks_addon" "coredns" {
  provider             = aws.account
  cluster_name         = aws_eks_cluster.cluster.name
  addon_name           = "coredns"
  addon_version        = "v1.8.7-eksbuild.3"
  configuration_values = jsonencode({ computeType = "Fargate" })
  resolve_conflicts    = "OVERWRITE"
  tags                 = merge(var.tags, local.default_tags)
  depends_on           = [aws_eks_fargate_profile.coredns]
}

resource "aws_eks_fargate_profile" "coredns" {
  provider               = aws.account
  cluster_name           = aws_eks_cluster.cluster.name
  fargate_profile_name   = "CoreDNS"
  pod_execution_role_arn = aws_iam_role.pods.arn
  subnet_ids             = var.subnet_ids
  tags                   = merge(var.tags, local.default_tags)

  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
    }
  }
}

################################################################################
# Security Group
################################################################################
resource "aws_security_group" "cluster" {
  provider               = aws.account
  name                   = format("%s-cluster", local.full_cluster_name)
  description            = format("Security Group for the %s EKS Cluster", local.full_cluster_name)
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    var.tags,
    local.default_tags,
    {
      Name = format("%s-cluster", local.full_cluster_name)
    }
  )
}


################################################################################
# IAM Role
################################################################################
resource "aws_iam_role" "cluster" {
  provider           = aws.account
  name               = local.full_cluster_name
  assume_role_policy = data.aws_iam_policy_document.assume_eks.json
  tags               = merge(var.tags, local.default_tags)
}

data "aws_iam_policy_document" "assume_eks" {
  provider = aws.account
  statement {
    sid     = "AssumeEKS"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "amazon_managed_policies_cluster" {
  provider   = aws.account
  for_each   = local.amazon_managed_policies["cluster"]
  policy_arn = format("arn:aws:iam::aws:policy/%s", each.value)
  role       = aws_iam_role.cluster.name
}


################################################################################
# CloudWatch Logging
################################################################################
resource "aws_cloudwatch_log_group" "cluster" {
  provider          = aws.account
  name              = format("/aws/eks/%s", local.full_cluster_name)
  retention_in_days = var.log_retention_period
}


################################################################################
# Pod Execution Role
################################################################################
resource "aws_iam_role" "pods" {
  provider           = aws.account
  name               = format("%s-pod-execution", local.full_cluster_name)
  assume_role_policy = data.aws_iam_policy_document.assume_eks_pods.json
  tags               = merge(var.tags, local.default_tags)
}

data "aws_iam_policy_document" "assume_eks_pods" {
  provider = aws.account
  statement {
    sid     = "AssumeEKS"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [format("arn:aws:eks:%s:%s:fargateprofile/%s/*", data.aws_region.region.name, data.aws_caller_identity.account.account_id, local.full_cluster_name)]
    }
  }
}

resource "aws_iam_role_policy_attachment" "amazon_managed_policies_pods" {
  provider   = aws.account
  for_each   = local.amazon_managed_policies["pods"]
  policy_arn = format("arn:aws:iam::aws:policy/%s", each.value)
  role       = aws_iam_role.pods.name
}
