################################################################################
# Global Variables
################################################################################
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
  description = "Name of the EKS Cluster to configure for ingress routing"
  type        = string
}

variable "pod_execution_role_arn" {
  description = "ARN of the Pod Execution IAM Role"
  type        = string
}


################################################################################
# Network Variables
################################################################################
variable "vpc_id" {
  description = "ID of the VPC in which the EKS Cluster is provisioned"
  type        = string
}

variable "subnet_ids" {
  description = "List of Subnet IDs in which aws-load-balancer-controller is launched"
  type        = list(any)
}


################################################################################
# OpenID/ELB Variables
################################################################################
/* variable "thumbprints" {
  description = "Map of thumbprints used to associate EKS OIDC Providers with IAM"
  type        = map(string)
  default = {
    eu-north-1     = "3ACE16CA6BAE7B16AAE3707096D1DE7D29093AD8"
    ap-south-1     = "59ADE3A3A6039BBA092E920FEE413466493F409C"
    eu-west-3      = "3FB881BCACBD420928168C739B07EEF47555946B"
    eu-west-2      = "7CA6BE9F14E20973CB2C58452DA9B1E2BEB7236B"
    eu-west-1      = "CAB073498D7558FEC3B2C414C006ACBA30805431"
    ap-northeast-2 = "2EAFC197C15CDEE5426BFD4D27D3321A685F3B78"
    ap-northeast-1 = "B715DC079832DA5FC1D4706515BE48BE79A1C871"
    sa-east-1      = "CB454452665937052981CA118417B7A162A25F54"
    ca-central-1   = "1C8B5245E80A6B7A0E8BF5FFDAB032273D7D5DF1"
    ap-southeast-1 = "F719C49FEA86549E159818880E392C1570C953B6"
    ap-southeast-2 = "0148872FA02F3A7D6B38AA88FA5397228B28E08B"
    eu-central-1   = "9884072430220E6253011B88F940E4F20F53D0CC"
    us-east-1      = "598ADECB9A3E6CC70AA53D64BD5EE4704300382A"
    us-east-2      = "750B948515281953BC6F3D717A1E1654ECBFA852"
    us-west-1      = "89BABC6D46502653516CC0BA38B14A2B7864D161"
    us-west-2      = "63966130761608209718C5045CFFB4856FB53976"
  }
} */
