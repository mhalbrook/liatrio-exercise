###############################################################################
# Cluster Outputs
###############################################################################
output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_arn" {
  value = module.cluster.cluster_arn
}

output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}

output "cluster_token" {
  value     = module.cluster.cluster_token
  sensitive = true
}

output "cluster_certificate" {
  value = module.cluster.cluster_certificate_authority[0].data
}

output "pod_exec_role_arn" {
  value = module.cluster.pod_exec_role_arn
}
