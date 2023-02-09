################################################################################
#  Locals
################################################################################
##########################################################
#  Global locals
##########################################################
locals {
  environment = element(split("-", terraform.workspace), 0)                                                   # identify Environments by removing suffix (region) from Terraform Workspace. [split workspace into list, separated by '-'; get first element]
  region      = join("-", slice(split("-", terraform.workspace), 1, length(split("-", terraform.workspace)))) # identify region by removing the prefix (environment) from the Terraform Workspace. [split workspace into list, separated by '-'; remove first element; join list to string separated by '-']
}


################################################################################
#  EKS Cluster
################################################################################
module "cluster" {
  source       = "../../.modules/eks-cluster"
  project      = var.project
  environment  = local.environment
  cluster_name = var.service_name
  vpc_id       = data.terraform_remote_state.vpc.outputs.vpc_id["services"]
  subnet_ids   = data.terraform_remote_state.vpc.outputs.private_subnet_ids["services"]
  #cluster_node_vpc_cidr = data.terraform_remote_state.vpc.outputs.vpc_cidr["services"]
  log_retention_period = 1

  providers = {
    aws.account = aws.account
  }
}

module "elb_controller_config" {
  source                 = "../../.modules/eks-ingress-config"
  environment            = local.environment
  cluster_name           = module.cluster.cluster_name
  vpc_id                 = data.terraform_remote_state.vpc.outputs.vpc_id["services"]
  subnet_ids             = data.terraform_remote_state.vpc.outputs.private_subnet_ids["services"]
  pod_execution_role_arn = module.cluster.pod_exec_role_arn
  depends_on             = [module.cluster]

  providers = {
    aws.account = aws.account
    kubernetes  = kubernetes
    helm        = helm
    tls         = tls
  }
}

################################################################################
#  DNS Node
################################################################################
/* module "dns_node" {
  source                 = "../../.modules/eks-node"
  project                = var.project
  environment            = local.environment
  cluster_name           = module.cluster.cluster_name
  namespace              = "kube-system"
  node_name              = "CoreDNS"
  override_naming_schema = true
  is_dns_resolver        = true
  subnet_ids             = data.terraform_remote_state.vpc.outputs.private_subnet_ids["services"]
  pod_execution_role_arn = module.cluster.pod_exec_role_arn
  depends_on             = [module.elb_controller_config]

  labels = {
    k8s-app = "kube-dns"
  }

  providers = {
    aws.account = aws.account
    kubernetes  = kubernetes
  }
} */

/* module "elb_controller" {
  source                 = "../../.modules/eks-node"
  project                = var.project
  environment            = local.environment
  cluster_name           = module.cluster.cluster_name
  namespace              = "kube-system"
  node_name              = "aws-load-balancer-controller"
  override_naming_schema = true
  is_elb_controller      = true
  subnet_ids             = data.terraform_remote_state.vpc.outputs.private_subnet_ids["services"]
  depends_on = [module.elb_controller_config]
  labels = {
    "app.kubernetes.io/name" = "aws-load-balancer-controller"
  }

  providers = {
    aws.account = aws.account
    kubernetes  = kubernetes
  }
} */

################################################################################
#  Namespaces
################################################################################
resource "kubernetes_namespace" "namespace" {
  provider   = kubernetes
  for_each   = toset(var.namespaces)
  depends_on = [module.cluster]
  metadata {
    name = each.value
  }
}
