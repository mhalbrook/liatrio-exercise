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
  config_path    = "~/.kube/config"
  config_context = data.terraform_remote_state.cluster.outputs.cluster_arn
}
