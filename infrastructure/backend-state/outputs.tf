output "backend_bucket" {
  value = module.backend_s3.bucket_name[var.region]
}

output "backend_region" {
  value = var.region
}
