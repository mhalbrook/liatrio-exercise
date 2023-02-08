################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "Environment that the App Mesh will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "service_name" {
  description = "Name of the repository"
  type        = string
}

variable "project" {
  description = "Name of the Project the infrastructure supports"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of additional tags to add to the resources provisioned by the module"
  type        = map(string)
  default     = {}
}


################################################################################
# ECR Repository Variables
################################################################################
variable "kms_key_arn" {
  description = "ARN of the KMS Key used to encrypt images in the ECR Repository"
  type        = string
}

variable "lifecycle_policy" {
  description = "Custom Lifecycle Policy to attach to the ECR Repository"
  type        = string
  default     = null
}

variable "enable_tag_immutability" {
  description = "Sets whether to make Image Tags Immutable"
  type        = bool
  default     = true
}

variable "pull_through_cache" {
  description = "Sets whether the repository is used as a pull through cache"
  type        = bool
  default     = false
}

variable "pull_through_cache_image_namespace" {
  description = "The Namespace of the Public Image being pulled via Pull Through Cache"
  type        = string
  default     = null
}
