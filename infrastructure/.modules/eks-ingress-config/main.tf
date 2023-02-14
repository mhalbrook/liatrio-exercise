################################################################################
# Locals
################################################################################
#############################################################
# Tagging Locals
#############################################################
locals {
  default_tags = {
    builtby     = "terraform"
    environment = var.environment
  }
}

################################################################################
# OpenID Connect
################################################################################

resource "aws_eks_identity_provider_config" "oidc" {
  provider     = aws.account
  cluster_name = var.cluster_name
  oidc {
    client_id                     = "sts.amazonaws.com"
    identity_provider_config_name = var.cluster_name
    issuer_url                    = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  }
}

resource "aws_iam_openid_connect_provider" "oidc" {
  provider        = aws.account
  url             = aws_eks_identity_provider_config.oidc.oidc[0].issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "elb_controller" {
  provider           = aws.account
  name               = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.assume_oidc.json
  tags               = merge(var.tags, local.default_tags)
}

data "aws_iam_policy_document" "assume_oidc" {
  provider = aws.account
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    dynamic "condition" {
      for_each = zipmap(
        formatlist("%s:%s", trimprefix(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://"), ["aud", "sub"]),
        ["sts.amazonaws.com", "system:serviceaccount:kube-system:aws-load-balancer-controller"]
      )
      content {
        test     = "StringEquals"
        variable = condition.key
        values   = [condition.value]
      }
    }
  }
}

################################################################################
# Load Balancing Controller 
################################################################################
resource "aws_eks_fargate_profile" "elb_controller" {
  provider               = aws.account
  cluster_name           = var.cluster_name
  fargate_profile_name   = "aws-load-balaner-controller"
  pod_execution_role_arn = var.pod_execution_role_arn
  subnet_ids             = var.subnet_ids
  tags                   = merge(var.tags, local.default_tags)
  depends_on             = [aws_eks_identity_provider_config.oidc]

  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
}

################################################################################
#  Service-Linked IAM Role
################################################################################
data "aws_iam_policy_document" "elb_controller" {
  provider = aws.account
  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:CreateSecurityGroup"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags", "ec2:DeleteTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*", "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*", "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"]
  }
  statement {
    effect  = "Allow"
    actions = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "elb_controller" {
  provider    = aws.account
  name        = format("%s-elb-controller", var.cluster_name)
  description = format("Policy enabling ELB Controller for %s EKS Cluster", var.cluster_name)
  policy      = data.aws_iam_policy_document.elb_controller.json
}

resource "aws_iam_role_policy_attachment" "elb_controller" {
  provider   = aws.account
  policy_arn = aws_iam_policy.elb_controller.arn
  role       = aws_iam_role.elb_controller.name
}


################################################################################
# Kubernetes resources
################################################################################
resource "kubernetes_service_account" "elb_controller" {
  provider   = kubernetes
  depends_on = [aws_iam_openid_connect_provider.oidc, aws_eks_fargate_profile.elb_controller]
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/instance"   = "aws-load-balancer-controller"
      "app.kubernetes.io/version"    = "v2.4.6"
      "helm.sh/chart"                = "aws-load-balancer-controller-2.4.6"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.elb_controller.arn
      "meta.helm.sh/release-name"      = "aws-load-balancer-controller"
      "meta.helm.sh/release-namespace" = "kube-system"
    }
  }

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "kubernetes_cluster_role" "elb_controller" {
  provider   = kubernetes
  depends_on = [aws_iam_openid_connect_provider.oidc, aws_eks_fargate_profile.elb_controller]
  metadata {
    name = "aws-load-balancer-controller-role"
    labels = {
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/instance"   = "aws-load-balancer-controller"
      "app.kubernetes.io/version"    = "v2.4.6"
      "helm.sh/chart"                = "aws-load-balancer-controller-2.4.6"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"     = "aws_iam_role.elb_controller.arn"
      "meta.helm.sh/release-name"      = "aws-load-balancer-controller"
      "meta.helm.sh/release-namespace" = "kube-system"
    }
  }
}


################################################################################
# Kubernetes aws-load-balancer-controller Add-On
################################################################################
resource "helm_release" "elb_controller" {
  provider   = helm
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  timeout    = 600
  version    = "1.4.7"
  depends_on = [kubernetes_cluster_role.elb_controller, kubernetes_service_account.elb_controller]
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }
  set {
    name  = "image.tag"
    value = "v2.4.6"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.elb_controller.metadata[0].name
  }
  set {
    name  = "region"
    value = data.aws_region.region.name
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}
