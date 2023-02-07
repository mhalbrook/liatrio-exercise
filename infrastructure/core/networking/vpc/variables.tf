################################################################################
#  Global Variables
################################################################################
variable "project" {
  description = "Name of the project the service supports"
  type        = string
  default     = "interview-mitch-halbrook"
}

variable "vpc_cidr" {
  description = "CIDR adress of the VPC"
  type        = string
  default     = "10.1.0.0/16"
}
