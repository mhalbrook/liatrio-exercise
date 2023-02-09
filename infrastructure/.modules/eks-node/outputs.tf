################################################################################
# Ingress Ouputs
################################################################################
output "load_balancer_hostname" {
  value = try(kubernetes_ingress_v1.ingress[0].status[0].load_balancer[0].ingress[0].hostname, null)
}
