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

##########################################################
#  Repo locals
##########################################################
locals {
  repos = ["service-a"]
}

################################################################################
#  ECR KMS Key
################################################################################
module "kms" {
  source      = "../../.modules/kms"
  environment = local.environment
  service     = "ecr"
  suffix      = "ecr"

  providers = {
    aws.account   = aws.account
    aws.secondary = aws.account
    aws.tertiary  = aws.account
  }
}

################################################################################
#  ECR Repositories
################################################################################
module "ecr" {
  source                  = "../../.modules/ecr"
  for_each                = toset(local.repos)
  environment             = local.environment
  project                 = var.project
  service_name            = each.key
  kms_key_arn             = module.kms.key_arn[local.region]
  enable_tag_immutability = false

  providers = {
    aws.account = aws.account
  }
}
