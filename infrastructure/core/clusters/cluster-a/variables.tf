################################################################################
#  Global Variables
################################################################################
variable "project" {
  description = "Name of the project the service supports"
  type        = string
  default     = "interview-mitch-halbrook"
}

variable "service_name" {
  description = "Name of the Service"
  type        = string
  default     = "cluster-a"
}

variable "namespaces" {
  description = "List of Kubernetes namespaces to provision to the cluster"
  type = list 
  default = ["liatrio"]
}
