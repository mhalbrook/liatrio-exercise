##########################################################
# Required providers Configuration
##########################################################
terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "< 5.0.0"
      configuration_aliases = [aws.account]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "< 3.0.0"
    }
  }
}

provider "aws" {
  alias                    = "account"
  region                   = local.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "halbromr"
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_certificate)
  token                  = data.terraform_remote_state.cluster.outputs.cluster_token
}