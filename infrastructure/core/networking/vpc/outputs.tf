################################################################################
#  VPC Outputs
################################################################################
output "vpc_id" {
  value = {
    tools = module.tools.vpc_id
    services = module.services.vpc_id
  }
}

output "vpc_cidr" {
  value = {
    tools = module.tools.vpc_cidr
    services = module.services.vpc_cidr
  }
}

output "private_subnet_ids" {
  value = {
    tools = module.tools.subnet_ids["private"]
    services = module.services.subnet_ids["private"]
  }
}

output "private_subnet_cidrs" {
  value = {
    tools = module.tools.subnet_cidrs["private"]
    services = module.services.subnet_cidrs["private"]
  }
}
