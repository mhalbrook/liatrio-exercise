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
