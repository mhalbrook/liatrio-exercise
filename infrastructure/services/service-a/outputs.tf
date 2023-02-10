################################################################################
# Service Ouputs
################################################################################
output "service_url" {
  value = module.service_a.load_balancer_hostname
}

output "load_balancer_name" {
  value = join("-", slice(split("-", split(".", module.service_a.load_balancer_hostname)[0]), 0, length(split("-", split(".", module.service_a.load_balancer_hostname)[0])) - 1))
}
