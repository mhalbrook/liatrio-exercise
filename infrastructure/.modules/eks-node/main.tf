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
  pod_execution_role_arn = var.pod_execution_role_arn
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
  metadata {
    name      = var.node_name
    labels    = var.labels
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
        container {
          image = var.container_image
          name  = var.node_name
          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }
          resources {
            limits = {
              cpu    = format("%sm", var.cpu_limit)
              memory = format("%sMi", var.memory_limit)
            }
          }
          liveness_probe {
            initial_delay_seconds = 120
            period_seconds        = 5
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
        max_surge       = "200%"
        max_unavailable = "100%"
      }
    }
  }
  depends_on = [aws_eks_fargate_profile.node]
}


################################################################################
# Kubernetes Ingress
################################################################################
resource "kubernetes_ingress_v1" "ingress" {
  provider               = kubernetes
  count                  = var.enable_ingress ? 1 : 0
  wait_for_load_balancer = true
  metadata {
    name      = format("%s-ingress", var.node_name)
    namespace = var.namespace
    labels    = var.labels
    annotations = {
      "eks.amazonaws.com/role-arn"            = "arn:aws:iam::173070050511:role/AmazonEKSLoadBalancerControllerRole"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/tags"        = "service_name=var.node_name"
    }
  }
  spec {
    ingress_class_name = "alb"
    default_backend {
      service {
        name = kubernetes_service.service.metadata[0].name
        port {
          number = var.port
        }
      }
    }
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.service.metadata[0].name
              port {
                number = var.port
              }
            }
          }
        }
      }
    }
  }
}
