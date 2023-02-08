################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "The environment the VPC supports"
  type        = string
}

variable "tags" {
  description = "A map of additional tags to add to specific resources"
  type        = map(string)
  default     = {}
}

variable "default_tags" {
  description = "Map of tags to be used on all resources created by the module"
  type        = map(any)

  default = {
    builtby               = "terraform"
    "data classification" = "internal confidential"
  }
}


################################################################################
# VPC Variables
################################################################################
variable "vpc_name" {
  description = "Friendly name for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to configured in the VPC"
  type        = number
  default     = 2
}

variable "subnet_mask_slash_notation" {
  description = "The slash-notation number to designate the size of the private and data subnets"
  type        = number
  default     = 24
}

variable "enable_flow_logs" {
  description = "Sets whether to enable flow logs from the VPC. When 'true', requires an AWS Logging S3 Bucket ot be provisioned"
  type        = bool
  default     = true
}

################################################################################
# NACL Variables
################################################################################
variable "application_ports" {
  description = "list of Ports on which the applications within the Private Subnet of the VPC will listen"
  type        = list(any)
  default     = []
}

variable "database_ports" {
  description = "list of Ports on which the databases within the VPC will listen"
  type        = list(any)
  default     = []
}

variable "enable_icmp" {
  description = "sets whether to generate NACL Rules allowing ICMP (ping) connections from Local networks"
  type        = bool
  default     = false
}

variable "enable_udp" {
  description = "sets whether to generate NACL Rules allowing inbound UDP connections on ephemeral ports"
  type        = bool
  default     = false
}

################################################################################
# VPC Endpoint Variables
################################################################################
variable "enabled_vpc_endpoints" {
  description = "List of AWS Services for which VPC Endpoints should be provisioned"
  type        = list(string)
  default     = ["s3", "dynamodb", "cloudwatch", "ec2", "autoscaling", "ebs", "ecs"]
}


################################################################################
# Gateway Variables
################################################################################
variable "internet_enabled" {
  description = "Sets whether to enable inbound internet traffic via an Internet Gateway"
  type        = bool
  default     = true
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway to which the VPC is attached"
  type        = string
  default     = null
}


################################################################################
# Namespace Variables
################################################################################
variable "namespaces" {
  description = "Name(s) of the CloudMap Namespace(s) to which the VPC is associated"
  type        = any
  default     = null
}
