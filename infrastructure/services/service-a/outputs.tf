################################################################################
# Service Ouputs
################################################################################
output "service_url" {
  value = module.service_a.load_balancer_hostname
}