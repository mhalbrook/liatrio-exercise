################################################################################
# DynamoDB Table Outputs
################################################################################
output "table_name" {
  value = aws_dynamodb_table.table.name
}

output "table_arn" {
  value = aws_dynamodb_table.table.arn
}

output "table_id" {
  value = aws_dynamodb_table.table.id
}

output "table_hash_key" {
  value = aws_dynamodb_table.table.hash_key
}

output "table_range_key" {
  value = aws_dynamodb_table.table.range_key
}

output "stream_arn" {
  value = aws_dynamodb_table.table.stream_arn
}

output "stream_label" {
  value = aws_dynamodb_table.table.stream_label
}

output "stream_id" {
  value = format("%s%s%s", data.aws_caller_identity.account.id, aws_dynamodb_table.table.name, aws_dynamodb_table.table.stream_label)
}


################################################################################
# IAM Role Outputs
################################################################################
###########################################
# Read-Only Role Outputs
###########################################
output "read_only_role_arn" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.arn }, "read_only", null)
}

output "read_only_role_id" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.id }, "read_only", null)
}

output "read_only_role_name" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.name }, "read_only", null)
}

output "read_only_role_unique_id" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.unique_id }, "read_only", null)
}

###########################################
# Write Role Outputs
###########################################
output "write_role_arn" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.arn }, "write", null)
}

output "write_role_id" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.id }, "write", null)
}

output "write_role_name" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.name }, "write", null)
}

output "write_role_unique_id" {
  value = lookup({ for k, v in aws_iam_role.role : k => v.unique_id }, "write", null)
}