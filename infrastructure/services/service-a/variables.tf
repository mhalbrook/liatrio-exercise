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
  default     = "service-a"
}

variable "container_image_tag" {
  description = "Tag of the container image to deploy"
  type        = string
  default     = "v1.0"
}

variable "app_port" {
  description = "Port on which the service listens"
  type        = number
  default     = 8080
}
