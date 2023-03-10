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
  }
}

provider "aws" {
  alias                    = "account"
  region                   = local.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
}
