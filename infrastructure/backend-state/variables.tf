################################################################################
#  Global Variables
################################################################################
variable "project" {
  description = "Name of the project the service supports"
  type        = string
  default     = "interview-mitch-halbrook"
}

variable "region" {
  description = "The AWS Region in which to provision the backend state resources"
  type        = string
  default     = "us-east-1"
}
