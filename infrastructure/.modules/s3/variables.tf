################################################################################
# Global Variables
################################################################################
variable "project" {
  description = "Friendly name of the project the S3 Bucket supports. Allows naming convention to be overriden when the bucket should not be named after the account in which it resides."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment that the S3 bucket will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "data_classification" {
  description = "Classification of data stored in the S3 bucket. Valid options are 'public', 'strategic', 'internal confidential' or 'client confidential'"
  type        = string
}

variable "tags" {
  description = "A map of additional tags to add to specific resources"
  type        = map(string)
  default     = {}
}

variable "default_tags" {
  description = "map of tags to be used on all resources created by the module"
  type        = map(any)
  default = {
    builtby = "terraform"
  }
}

################################################################################
# Bucket Variables
################################################################################
variable "bucket_name" {
  description = "Friendly name for the S3 bucket"
  type        = string
}

variable "is_logging_bucket" {
  description = "Set to true if this is the primary logging bucket for the account"
  type        = bool
  default     = false
}

variable "suppress_region" {
  description = "Sets whether to suppress the AWS Region from the AWS Bucket Name"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Sets whether the bucket should be configured to deliver access logs to another S3 Bucket"
  type        = bool
  default     = true
}

#############################################################
# Encryption
#############################################################
variable "kms_key_arns" {
  description = "List of ARN(s) of the KMS key used to encrypt the S3 bucket(s)"
  type        = list(any)
}

#############################################################
# Bucket Policies
#############################################################
variable "default_bucket_policy" {
  description = "Sets whether to attach a default bucket policy"
  type        = bool
  default     = true
}

#############################################################
# Replication
#############################################################
variable "replication_region_count" {
  description = "Sets the number of AWS Regions in which to provision identical buckets with replication"
  type        = number
  default     = 0
}

variable "sync_buckets" {
  description = "Sets whether to configure replication between each bucket to keep all buckets in-sync"
  type        = bool
  default     = false
}

variable "enable_rtc" {
  description = "Sets whether to enable Replication Time Control (RTC) to enfore 15 minute replication of objects"
  type        = bool
  default     = false
}

#############################################################
# Lifecycle Rules
#############################################################
variable "lifecycle_rules" {
  description = "Map of values to set lifecycle rules for the buckets"
  type        = map(any)
  default     = {}
}

#############################################################
# CORS
#############################################################
variable "allowed_headers" {
  description = "specifies headers allowed via CORS policy"
  type        = list(any)
  default     = null
}

variable "allowed_methods" {
  description = "specifies methods that are allowed via CORS policy"
  type        = list(any)
  default     = null
}

variable "allowed_origins" {
  description = "specifies origins that are allowed via CORS policy"
  type        = list(any)
  default     = null
}

variable "expose_headers" {
  description = "specifies which headers are exposed in responses via CORS policy"
  type        = list(any)
  default     = null
}

variable "max_age_seconds" {
  description = "specifies amount of time (s) that browsers can cache the response for a preflight request via CORS policy"
  type        = number
  default     = 3000
}

#############################################################
# CloudTrail
#############################################################
variable "enable_cloudtrail" {
  description = "Sets whether to create an AWS CloudTrail Trail for S3 Events"
  type        = bool
  default     = false
}

#############################################################
# Force Delete
#############################################################
variable "delete_unemptied_bucket" {
  description = "Sets whether to allow S3 Buckets, that are not empty, to be deleted"
  type        = bool
  default     = false
}