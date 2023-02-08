################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "Environment that the nlb will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
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
# KMS Key Variables
################################################################################
variable "service" {
  description = "The service that the KMS Key is used to encrypt"
  type        = string
}

variable "suffix" {
  description = "Suffix for the service that the KMS Key is used to encrypt (i.e. 'S3' or 'plfrm'). Used to shorten aliases"
  type        = string
}

#############################################################
# Multi-Region Variables
#############################################################
variable "replication_region_count" {
  description = "Sets the number of AWS Regions in which to provision identical buckets with replication"
  type        = number
  default     = 0
}

#############################################################
# Key Policy Variables
#############################################################
variable "key_policy" {
  description = "custom KMS key policy for access to key. Default policy is created if a custom policy is not passed from root"
  default     = null
}

#############################################################
# Logging key Variables
#############################################################
variable "is_logging_key" {
  description = "Sets whether the KMS Key is used to encrypt S3 Buckets that collect Access Logs from Load Balancers and/or S3 Buckets"
  default     = false
}