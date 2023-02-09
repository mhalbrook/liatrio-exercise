################################################################################
#  Locals
################################################################################
##########################################################
#  Global Locals
##########################################################
locals {
  environment = element(split("-", terraform.workspace), 0)                                                   # identify Environments by removing suffix (region) from Terraform Workspace. [split workspace into list, separated by '-'; get first element]
  region      = join("-", slice(split("-", terraform.workspace), 1, length(split("-", terraform.workspace)))) # identify region by removing the prefix (environment) from the Terraform Workspace. [split workspace into list, separated by '-'; remove first element; join list to string separated by '-']
}

##########################################################
#  Tagging Locals
##########################################################
locals {
  default_tags = {
    builtby     = "terraform"
    environment = "core"
  }
}

##########################################################
#  Terraform Backend KMS Key
##########################################################
module "backend_kms" {
  source      = "../.modules/kms"
  environment = local.environment
  service     = "terraform-backend"
  suffix      = "terraform-backend"

  providers = {
    aws.account   = aws.account
    aws.secondary = aws.account
    aws.tertiary  = aws.account
  }
}


##########################################################
#  S3 Access Terraform Backend
##########################################################
module "backend_s3" {
  source                  = "../.modules/s3"
  project                 = var.project
  environment             = local.environment
  bucket_name             = "terraform-state-backend"
  kms_key_arns            = [module.backend_kms.key_arn[data.aws_region.region.name]]
  data_classification     = "internal"
  enable_access_logs      = false
  delete_unemptied_bucket = true

  providers = {
    aws.account   = aws.account
    aws.secondary = aws.account
    aws.tertiary  = aws.account
  }
}


##########################################################
#  Terraform State Lock DynamoDB Table
##########################################################
module "terraform_state_lock" {
  source              = "../.modules/dynamodb"
  project             = var.project
  environment         = local.environment
  table_name          = "terraform-state-lock"
  hash_key            = { "LockID" = "S" }
  kms_key_arn         = module.backend_kms.key_arn[data.aws_region.region.name]
  data_classification = "internal"

  providers = {
    aws.account = aws.account
  }
}
