terraform {
  backend "s3" {
    bucket         = "us-east-1-interview-mitch-halbrook-terraform-state-backend"
    region         = "us-east-1"
    profile        = "default"
    key            = "core/networking/vpc/terraform.tfstate"
    dynamodb_table = "us-east-1-interview-mitch-halbrook-demo-terraform-state-lock"
  }
}
