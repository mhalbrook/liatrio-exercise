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
  description = "Name of the EKS Cluster to which the EKS Node is associated"
  type        = string
}

variable "pod_execution_role_arn" {
  description = "ARN of the Pod Execution IAM Role"
  type        = string
}

################################################################################
# Node Variables
################################################################################
variable "node_name" {
  description = "Friendly name for the EKS Node"
  type        = string
}

variable "override_naming_schema" {
  description = "Sets whether to override the naming schema, which sets the Node Name without the region, environment, etc."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Name of the Kubernetes Namespace"
  type        = string
  default     = "default"
}

variable "labels" {
  description = "Map of Kubernetes Labels"
  type        = map(any)
  default     = {}
}

variable "service_type" {
  description = "The type of Kubernetes service to provision"
  type        = string
  default     = "ClusterIP"
}

variable "cpu_limit" {
  description = "The maximum amount of CPU allocated to the Kubernetes Pods"
  type        = number
  default     = 0.5
}

variable "memory_limit" {
  description = "The maximum amount of Memory allocater to the Kubernetes Pods"
  type        = number
  default     = 50
}

variable "desired_count" {
  description = "The number of Kubernetes Pods that should be running"
  type        = number
  default     = 1
}

variable "container_image" {
  description = "The Container Image run on the Kubernetes Pods"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Map of environment variables to set for the service"
  type        = map(any)
  default     = {}
}

################################################################################
# Network Variables
################################################################################
variable "port" {
  description = "The port on which the service listens"
  type        = number
  default     = 8080
}

variable "protocol" {
  description = "The protocol on which the service receives traffic"
  type        = string
  default     = "tcp"
}

variable "subnet_ids" {
  description = "List of Subnet IDs in which Node is provisioned"
  type        = list(any)
}


################################################################################
# Health Check Variables
################################################################################
variable "healthcheck_port" {
  description = "The port used to perform healthchecks of Kubernetes Pods"
  type        = number
  default     = 0
}

variable "healthcheck_path" {
  description = "The path used to perform healthcheck of Kubernetes Pods"
  type        = string
  default     = "/health"
}

################################################################################
# Ingress Variables
################################################################################
variable "enable_ingress" {
  description = "Sets whether to create an ingress resource to publically serve the service"
  type        = bool
  default     = false
}
