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
#  EKS Node
################################################################################
module "service_a" {
  source                 = "../../.modules/eks-node"
  project                = var.project
  environment            = local.environment
  cluster_name           = data.terraform_remote_state.cluster.outputs.cluster_name
  node_name              = var.service_name
  namespace              = "liatrio"
  subnet_ids             = data.terraform_remote_state.vpc.outputs.private_subnet_ids["services"]
  cpu_limit              = 1
  memory_limit           = 50
  port                   = var.app_port
  container_image        = format("%s:%s", data.terraform_remote_state.ecr.outputs.repository_url[var.service_name], var.container_image_tag)
  healthcheck_path       = "/health"
  enable_ingress         = true
  pod_execution_role_arn = data.terraform_remote_state.cluster.outputs.pod_exec_role_arn
  environment_variables = {
    LOG_LEVEL = "INFO"
    MESSAGE   = "K8 is Fun!"
    PORT      = var.app_port
  }
  labels = {
    service = var.service_name
  }

  providers = {
    aws.account = aws.account
  }
}
