################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  account_name   = var.project == null ? data.aws_iam_account_alias.account_alias.account_alias : var.project                                                          # allow 'project' variable to overwrite account_name, otherwise set dynamically
  full_node_name = var.override_naming_schema ? var.node_name : format("%s-%s-%s-%s", data.aws_region.region.name, var.environment, local.account_name, var.node_name) # set name to align to standard schema
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
# IAM Locals
#############################################################
locals {
  aws_managed_policies = toset(["AmazonEKSFargatePodExecutionRolePolicy"])
}


################################################################################
# Node
################################################################################
resource "aws_eks_fargate_profile" "node" {
  provider               = aws.account
  cluster_name           = var.cluster_name
  fargate_profile_name   = local.full_node_name
  pod_execution_role_arn = aws_iam_role.node.arn
  subnet_ids             = var.subnet_ids
  tags                   = merge(var.tags, local.default_tags)

  selector {
    namespace = var.namespace
    labels    = var.labels
  }
}

################################################################################
# Kubernetes Service
################################################################################
resource "kubernetes_service" "service" {
  provider = kubernetes
  count    = var.is_dns_resolver ? 0 : 1
  metadata {
    name      = var.node_name
    namespace = var.namespace
  }
  spec {
    selector                = var.labels
    type                    = var.service_type
    internal_traffic_policy = "Cluster"
    port {
      app_protocol = var.protocol
      port         = var.port
      target_port  = var.port
    }
  }
}

resource "kubernetes_deployment" "deployment" {
  provider = kubernetes
  count    = var.is_dns_resolver ? 0 : 1
  metadata {
    name = var.node_name 
    labels = var.labels
    namespace = var.namespace
  }
  spec {
    replicas = var.desired_count 
    selector {
        match_labels = var.labels
    }
    template {
        metadata {
            labels = var.labels
        }
        spec {
            container  {
                image = var.container_image 
                name = var.node_name 
                resources {
                    limits = {
                        cpu = format("%sm", var.cpu_limit) 
                        memory = format("%sMi", var.memory_limit)
                    }
                }
                liveness_probe {
                    initial_delay_seconds = 120 
                    period_seconds = 5
                    http_get {
                        path = var.healthcheck_path 
                        port = var.healthcheck_port > 0 ? var.healthcheck_port : var.port
                    }
                }
            }
        }
    }
    strategy {
        type = "RollingUpdate"
        rolling_update {
            max_surge = "200%"
            max_unavailable = "100%"
        }
    }
  }

}
################################################################################
# IAM Role
################################################################################
resource "aws_iam_role" "node" {
  provider           = aws.account
  name               = local.full_node_name
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
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [format("arn:aws:eks:%s:%s:fargateprofile/%s/*", data.aws_region.region.name, data.aws_caller_identity.account.account_id, var.cluster_name)]
    }
  }
}

resource "aws_iam_role_policy_attachment" "amazon_managed_policies" {
  provider   = aws.account
  for_each   = local.aws_managed_policies
  policy_arn = format("arn:aws:iam::aws:policy/%s", each.value)
  role       = aws_iam_role.node.name
}


################################################################################
# DNS Override
################################################################################
resource "null_resource" "config" {
  count = var.is_dns_resolver ? 1 : 0
  provisioner "local-exec" {
    command = "kubectl patch deployment coredns -n kube-system --type json -p='[{\"op\": \"remove\", \"path\": \"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type\"}]'"
  }

  triggers = {
    cluster_arn = aws_eks_fargate_profile.node.arn
  }
}
