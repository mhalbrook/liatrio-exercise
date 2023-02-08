################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "environment that the infrastructure will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "project" {
  description = "Name of the Project the infrastructure supports"
  type        = string
  default     = null
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(any)
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
# Table Variables
################################################################################
variable "table_name" {
  description = "Friendly name for the DynamoDB Table"
  type        = string
}

variable "billing_mode" {
  description = "Sets billing method to charge based on the read/writes (PAY_PER_REQUEST) or to set a max read/write (PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "write_capacity" {
  description = "Sets the maximum write capacity for the table. Only valid if billing_mode is set to 'PROVISIONED'"
  type        = string
  default     = null
}

variable "read_capacity" {
  description = "Sets the maximum read capacity for the table. Only valid if billing_mode is set to 'PROVISIONED'"
  type        = string
  default     = null
}

variable "hash_key" {
  description = "Map of attribute name and type to be used as the hash (partition) key"
  type        = map(any)
}

variable "range_key" {
  description = "Map of attribute name and type to be used as the range (sort) key"
  type        = map(any)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the resources"
  type        = string
}

variable "enable_ttl" {
  description = "Sets whether or not to enable TTL"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "The firendly name for the Attrbiute where TTL is configured"
  type        = string
  default     = "expirationDate"
}

variable "data_classification" {
  description = "Data classification for the table. Valid options are 'confidential', 'internal_confidential' or 'public'"
  type        = string
}

variable "local_secondary_index" {
  description = "Map of LSIs, with keys of name, range_key and projection type. If projection_type is set to 'INCLUDE' a key of non_key_attributes is required"
  type        = map(any)
  default     = {}
}

variable "global_secondary_index" {
  description = "Map of GSIs, with keys of name, hash_key, range_key and projection type. If projection_type is set to 'INCLUDE' a key of non_key_attributes is required. If Billing mode is set to 'PROVISIONED', keys of write_capacity and read_capacity are required."
  type        = map(any)
  default     = {}
}

variable "stream_view_type" {
  description = "Sets what information is written to a table's stream when an item is modified"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}


################################################################################
# IAM Variables
################################################################################
variable "trusted_entities_read_only" {
  description = "List of accounts that are permitted to assume roles that allow read-only actions against the DynamoDB table"
  type        = list(any)
  default     = []
}

variable "trusted_entities_write" {
  description = "List of accounts that are permitted to assume roles that allow write actions against the DynamoDB table"
  type        = list(any)
  default     = []
}