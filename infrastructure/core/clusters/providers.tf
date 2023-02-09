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
    helm = {
      source  = "hashicorp/helm"
      version = "< 3.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "< 4.0.0"
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
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority[0].data)
  token                  = module.cluster.cluster_token
  /* config_path    = "~/.kube/config"
  config_context = module.cluster.cluster_arn */
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority[0].data)
    token                  = module.cluster.cluster_token
  }
}

provider "tls" {}

