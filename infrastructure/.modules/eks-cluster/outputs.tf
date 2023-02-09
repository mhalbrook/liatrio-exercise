################################################################################
# Cluster Ouputs
################################################################################
output "cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "cluster_arn" {
  value = aws_eks_cluster.cluster.arn
}

output "cluster_id" {
  value = aws_eks_cluster.cluster.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.cluster.certificate_authority
}

output "cluster_token" {
  value     = data.aws_eks_cluster_auth.token.token
  sensitive = true
}

################################################################################
# IAM Role Outputs
################################################################################
output "role_name" {
  value = aws_iam_role.cluster.name
}

output "role_arn" {
  value = aws_iam_role.cluster.arn
}

output "role_id" {
  value = aws_iam_role.cluster.id
}

output "role_unique_id" {
  value = aws_iam_role.cluster.unique_id
}


################################################################################
# Cloudwatch Log Group Outputs
################################################################################
output "log_group_name" {
  value = aws_cloudwatch_log_group.cluster.name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.cluster.arn
}


################################################################################
# Security Group Outputs
################################################################################
output "security_group_name" {
  value = aws_security_group.cluster.name
}

output "security_group_arn" {
  value = aws_security_group.cluster.arn
}

output "security_group_id" {
  value = aws_security_group.cluster.id
}

################################################################################
# Pod Execution IAM Role Outputs
################################################################################
output "pod_exec_role_name" {
  value = aws_iam_role.pods.name
}

output "pod_exec_role_arn" {
  value = aws_iam_role.pods.arn
}

output "pod_exec_role_id" {
  value = aws_iam_role.pods.id
}

output "pod_exec_role_unique_id" {
  value = aws_iam_role.pods.unique_id
}
