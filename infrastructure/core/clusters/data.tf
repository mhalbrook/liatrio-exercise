################################################################################
#  Network Inputs
################################################################################
data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket  = "us-east-1-interview-mitch-halbrook-terraform-state-backend"
    region  = "us-east-1"
    key     = "core/networking/vpc/terraform.tfstate"
    profile = "halbromr"
  }
}
