##########################################################
# Required providers Configuration
##########################################################
terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 5.0.0"
    }
  }
}

##########################################################
# Provider Configurations
##########################################################
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "halbromr"
}

provider "aws" {
  alias                    = "account"
  region                   = var.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "halbromr"
}
