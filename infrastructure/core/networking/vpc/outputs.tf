################################################################################
#  VPC Outputs
################################################################################
output "vpc_id" {
  value = {
    services = module.services.vpc_id
  }
}

output "vpc_cidr" {
  value = {
    services = module.services.vpc_cidr
  }
}

output "private_subnet_ids" {
  value = {
    services = module.services.subnet_ids["private"]
  }
}

output "private_subnet_cidrs" {
  value = {
    services = module.services.subnet_cidrs["private"]
  }
}
