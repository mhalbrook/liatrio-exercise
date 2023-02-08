################################################################################
# KMS Key Outputs
################################################################################
output "key_name" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_kms_alias.tertiary : trimprefix(v.name, "alias/")]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_kms_alias.secondary : trimprefix(v.name, "alias/")]), null)
    (data.aws_region.primary.name)   = one([for v in aws_kms_alias.primary : trimprefix(v.name, "alias/")])
  }
}

output "key_alias" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_kms_alias.tertiary : v.name]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_kms_alias.secondary : v.name]), null)
    (data.aws_region.primary.name)   = one([for v in aws_kms_alias.primary : v.name])
  }
}

output "key_arn" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_kms_key.tertiary : v.arn]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_kms_key.secondary : v.arn]), null)
    (data.aws_region.primary.name)   = one([for v in aws_kms_key.primary : v.arn])
  }
}

output "key_id" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_kms_key.tertiary : v.id]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_kms_key.secondary : v.id]), null)
    (data.aws_region.primary.name)   = one([for v in aws_kms_key.primary : v.id])
  }
}