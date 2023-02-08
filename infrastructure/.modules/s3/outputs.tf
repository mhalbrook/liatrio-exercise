################################################################################
# Bucket Outputs
################################################################################
output "bucket_name" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_s3_bucket.tertiary : v.bucket]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_s3_bucket.secondary : v.bucket]), null)
    (data.aws_region.primary.name)   = one([for v in aws_s3_bucket.primary : v.bucket])
  }
}

output "bucket_arn" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_s3_bucket.tertiary : v.arn]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_s3_bucket.secondary : v.arn]), null)
    (data.aws_region.primary.name)   = one([for v in aws_s3_bucket.primary : v.arn])
  }
}

output "bucket_id" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_s3_bucket.tertiary : v.id]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_s3_bucket.secondary : v.id]), null)
    (data.aws_region.primary.name)   = one([for v in aws_s3_bucket.primary : v.id])
  }
}

output "bucket_domain_name" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_s3_bucket.tertiary : v.bucket_domain_name]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_s3_bucket.secondary : v.bucket_domain_name]), null)
    (data.aws_region.primary.name)   = one([for v in aws_s3_bucket.primary : v.bucket_domain_name])
  }
}

output "bucket_hosted_zone_id" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_s3_bucket.tertiary : v.hosted_zone_id]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_s3_bucket.secondary : v.hosted_zone_id]), null)
    (data.aws_region.primary.name)   = one([for v in aws_s3_bucket.primary : v.hosted_zone_id])
  }
}

output "bucket_regional_domain_name" {
  value = {
    (data.aws_region.tertiary.name)  = try(one([for v in aws_s3_bucket.tertiary : v.bucket_regional_domain_name]), null)
    (data.aws_region.secondary.name) = try(one([for v in aws_s3_bucket.secondary : v.bucket_regional_domain_name]), null)
    (data.aws_region.primary.name)   = one([for v in aws_s3_bucket.primary : v.bucket_regional_domain_name])
  }
}


################################################################################
# Replication Role Outputs
################################################################################
output "bucket_replication_role_name" {
  value = try(aws_iam_role.replication[0].name, null)
}

output "bucket_replication_role_arn" {
  value = try(aws_iam_role.replication[0].arn, null)
}

output "bucket_replication_role_id" {
  value = try(aws_iam_role.replication[0].id, null)
}

output "bucket_replication_role_unique_id" {
  value = try(aws_iam_role.replication[0].unique_id, null)
}
