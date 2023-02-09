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
#  VPC
################################################################################
module "services" {
  source                     = "../../../.modules/vpc"
  vpc_name                   = format("%s-services", var.project)
  environment                = local.environment
  vpc_cidr                   = var.vpc_cidr["services"]
  availability_zone_count    = 2
  subnet_mask_slash_notation = 24
  application_ports          = [8080]
  enable_flow_logs           = false
  enabled_vpc_endpoints      = []

  providers = {
    aws.account = aws.account
  }
}

/* module "tools" {
  source                     = "../../../.modules/vpc"
  vpc_name                   = format("%s-tools", var.project)
  environment                = local.environment
  vpc_cidr                   = var.vpc_cidr["tools"]
  availability_zone_count    = 2
  subnet_mask_slash_notation = 24
  application_ports          = []
  enable_flow_logs           = false
  enabled_vpc_endpoints      = []

  providers = {
    aws.account = aws.account
  }
} */
