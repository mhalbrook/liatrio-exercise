################################################################################
# Global Variables
################################################################################
variable "project" {
  description = "Friendly name of the project the resources support. Allows naming convention to be overriden when the resource should not be named after the account in which it resides."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment that theresources will support. Valid options are 'dev', 'staging', 'prod', or 'core'"
  type        = string
}

variable "tags" {
  description = "A map of additional tags to add to specific resources"
  type        = map(string)
  default     = {}
}


################################################################################
# Cluster Variables
################################################################################
variable "cluster_name" {
  description = "Friendly name for the EKS Cluster"
  type        = string
}

variable "cluster_api_access" {
  description = "Sets whether the EKS Cluster API Endpoint should be available publically, or only from within the VPC"
  type        = string
  default     = "public"
}

variable "cluster_api_access_cidrs" {
  description = "List of CIDRs that are permitted access to the EKS Cluster API Endpoint, when publically accessible"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "kms_key_arn" {
  description = "ARN of the KMS Key used to encrypt the Cluster"
  type        = string
  default     = null
}

################################################################################
# Network Variables
################################################################################
variable "vpc_id" {
  description = "ID of the VPC in which to provision the Cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of Subnet IDs in which Cluster is provisioned"
  type        = list(any)
}

variable "cluster_node_vpc_cidr" {
  description = "CIDR of the VPC in which the Cluster will provision Nodes"
  type        = string
  default     = null
}

################################################################################
# Logging Variables
################################################################################
variable "log_types" {
  description = "List of log types to deliver to AWS Cloudwatch"
  type        = list(any)
  default     = ["api", "audit"]
}

variable "log_retention_period" {
  description = "The amount of time (days) for which logs should be retained in AWS CloudWatch"
  type        = number
  default     = 7
}

