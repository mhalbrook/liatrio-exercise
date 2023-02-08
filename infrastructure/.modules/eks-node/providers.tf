##########################################################
# Variable Account Provider
### provider configuration is passed in from root module
##########################################################
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.account]
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
