################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  full_vpc_name      = format("%s-%s-%s", data.aws_region.region.name, var.environment, var.vpc_name)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
}

#############################################################
# Subnet Address Locals
#############################################################
locals {
  vpc_cidr_mask  = tonumber(element(split("/", var.vpc_cidr), 1))                                                                                                                                                                              # get the slash-notation subnet mask number by removing trimming it from the full CIDR Notation
  subnet_newbits = var.subnet_mask_slash_notation - local.vpc_cidr_mask                                                                                                                                                                        # determine the number of newbits to add to the subnets (1.e. /16 vpc wih newbits of 4 will produce /20 subnets)
  first_subnet   = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 0)                                                                                                                                                                           # determine the first subnet; if creating /20 subnets, the public and transit subnets will be generated as /24s in this subnet to allow the maximization of prviate-layer subnets
  subnet_cidrs = var.subnet_mask_slash_notation < 24 ? {                                                                                                                                                                                       # if subnets are larger than /20, create the transit and public layers as /24 inside the first subnet to maximize the number of private/data subnets available, otherwise create all subnets as /24
    private = [for v in local.availability_zones : cidrsubnet(var.vpc_cidr, local.subnet_newbits, index(local.availability_zones, v) + 1)]                                                                                                     # start private subnet at second available subnet in /20 and create a subnet for each availability zone
    data    = [for v in local.availability_zones : cidrsubnet(var.vpc_cidr, local.subnet_newbits, 15 - length(local.availability_zones) + index(local.availability_zones, v) + 1)]                                                             # start data subnet as last avaailable /20 subnet and create a subnet for each availability zone 
    public  = flatten([for block in [local.first_subnet] : [for v in local.availability_zones : cidrsubnet(block, 24 - tonumber(element(split("/", block), 1)), index(local.availability_zones, v))]])                                         # start public subnet as first /24 avaialable inside the first /20 and create a subnet for each availability zone
    transit = flatten([for block in [local.first_subnet] : [for v in local.availability_zones : cidrsubnet(block, 24 - tonumber(element(split("/", block), 1)), 16 - length(local.availability_zones) + index(local.availability_zones, v))]]) # start transit subnet as last /24 avaialable inside the first /20 and create a subnet for each availability zone
    } : {                                                                                                                                                                                                                                      # if subnets are /24 create a subnet for each availability zone in 60-subnet blocks to evenely divide the total number of avaialable subnets
    public  = [for v in local.availability_zones : cidrsubnet(var.vpc_cidr, local.subnet_newbits, index(local.availability_zones, v))]
    private = [for v in local.availability_zones : cidrsubnet(var.vpc_cidr, local.subnet_newbits, index(local.availability_zones, v) + 60)]
    data    = [for v in local.availability_zones : cidrsubnet(var.vpc_cidr, local.subnet_newbits, index(local.availability_zones, v) + 120)]
    transit = [for v in local.availability_zones : cidrsubnet(var.vpc_cidr, local.subnet_newbits, index(local.availability_zones, v) + 180)]
  }
}

#############################################################
# Subnet Locals
#############################################################
locals {
  public_subnets = { # Create map of both public subnets, setting the subnet name as key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.public :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }

  private_subnets = { # Create map of both private subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.private :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }

  data_subnets = { # Create map of both data subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.data :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }

  transit_subnets = { # Create map of both Transit subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.transit :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }
}

#############################################################
# Route Table Locals
#############################################################
locals {
  public_route_tables = { # Create map of both public route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.public :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }

  private_route_tables = { # Create map of both private route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.private :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }

  data_route_tables = { # Create map of both data route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.data :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }

  transit_route_tables = { # Create map of both Transit route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.transit :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }
}

#############################################################
# NACL Locals
#############################################################
locals {
  private_nacl_database = {                                                                    # create matrix of database ports, matched to each Database Subnet to create NACl rules for Private Subnets when database ports are provided
    for pair in setproduct(var.database_ports, [for v in local.data_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; a database port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                     # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }

  data_nacl_database = {                                                                          # create matrix of database ports, matched to each Private Subnet to create NACl rules for Data Subnets when database ports are provided
    for pair in setproduct(var.database_ports, [for v in local.private_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; a database port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                        # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }

  public_nacl_application = {                                                                        # create matrix of application ports, matched to each Private Subnet to create NACl rules for Public Subnets when application ports are provided
    for pair in setproduct(var.application_ports, [for v in local.private_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; an application port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                           # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }

  private_nacl_application = {                                                                      # create matrix of application ports, matched to each Public Subnet to create NACl rules for Public Subnets when application ports are provided
    for pair in setproduct(var.application_ports, [for v in local.public_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; an application port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                          # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }
}

#############################################################
# VPC Endpoints Locals
#############################################################
locals {
  enabled_vpc_endpoints = [for v in var.enabled_vpc_endpoints : lower(v)]
  vpc_endpoints         = flatten([local.enabled_vpc_endpoints])
  interface_endpoints   = ["privateca", "appmesh", "ecs", "ebs", "autoscaling", "ec2", "cloudwatch"]
}


#############################################################
# Managed Prefix List Locals
#############################################################
locals {
  prefix_lists = {
    vpc = {
      cidrs = [aws_vpc.vpc.cidr_block]
      layer = "vpc"
    }
    nat_gateway = {
      cidrs = [for v in aws_nat_gateway.ngw : format("%s/32", v.public_ip)]
      layer = "nat"
    }
    public_subnets = {
      cidrs = [for s in aws_subnet.public : s.cidr_block]
      layer = "public"
    }
    private_subnets = {
      cidrs = [for s in aws_subnet.private : s.cidr_block]
      layer = "private"
    }
    data_subnets = {
      cidrs = [for s in aws_subnet.data : s.cidr_block]
      layer = "data"
    }
    transit_subnets = {
      cidrs = [for s in aws_subnet.transit : s.cidr_block]
      layer = "transit"
    }
  }
}

###############################################################################
# VPC
###############################################################################
resource "aws_vpc" "vpc" {
  provider             = aws.account
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = local.full_vpc_name
      environment = var.environment
    }
  )
}


###############################################################################
# Transit Gateway Attachment
###############################################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  provider           = aws.account
  count              = var.transit_gateway_id != null ? 1 : 0
  subnet_ids         = [for s in local.transit_subnets : s.subnet_id]
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-tgw-attachment", local.full_vpc_name)
      environment = var.environment
    }
  )
}


###############################################################################
# Gateways
###############################################################################
#############################################################
# Internet Gateway
#############################################################
resource "aws_internet_gateway" "igw" {
  provider = aws.account
  count    = var.internet_enabled ? 1 : 0
  vpc_id   = aws_vpc.vpc.id
  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-igw", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#############################################################
# NAT Gateways
#############################################################
resource "aws_eip" "nat" {
  provider = aws.account
  for_each = var.internet_enabled == true ? local.public_subnets : {}
  vpc      = true

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-ngw", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_nat_gateway" "ngw" {
  provider      = aws.account
  for_each      = var.internet_enabled == true ? local.public_subnets : {}
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.subnet_id
  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-ngw", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}


###############################################################################
# Subnets
###############################################################################
#############################################################
# Public subnets
#############################################################
resource "aws_subnet" "public" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(local.subnet_cidrs["public"], index(local.availability_zones, each.value))
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name                     = format("%s-public-subnet", replace(local.full_vpc_name, data.aws_region.region.name, each.value))
      environment              = var.environment
      layer                    = "public"
      availability_zone        = each.value
      "kubernetes.io/role/elb" = 1
    }
  )
}

#############################################################
# Private subnets
#############################################################
resource "aws_subnet" "private" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(local.subnet_cidrs["private"], index(local.availability_zones, each.value))
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name                              = format("%s-private-subnet", replace(local.full_vpc_name, data.aws_region.region.name, each.value))
      environment                       = var.environment
      layer                             = "private"
      availability_zone                 = each.value
      "kubernetes.io/role/internal-elb" = 1
    }
  )
}

#############################################################
# Data subnets
#############################################################
resource "aws_subnet" "data" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(local.subnet_cidrs["data"], index(local.availability_zones, each.value))
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-data-subnet", replace(local.full_vpc_name, data.aws_region.region.name, each.value))
      environment       = var.environment
      layer             = "data"
      availability_zone = each.value
    }
  )
}

#############################################################
# Transit Gateway subnets
#############################################################
resource "aws_subnet" "transit" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(local.subnet_cidrs["transit"], index(local.availability_zones, each.value))
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-transit-subnet", replace(local.full_vpc_name, data.aws_region.region.name, each.value))
      environment       = var.environment
      layer             = "transit"
      availability_zone = each.value
    }
  )
}


###############################################################################
# Route Tables and Default Routes
###############################################################################
#############################################################
# Publiс Route Tables
#############################################################
resource "aws_route_table" "public" {
  provider = aws.account
  for_each = local.public_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-public-route-table", replace(local.full_vpc_name, data.aws_region.region.name, each.value.availability_zone))
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "public" {
  provider       = aws.account
  for_each       = local.public_route_tables
  subnet_id      = element([for s in local.public_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "public_internet_gateway" {
  provider               = aws.account
  for_each               = var.internet_enabled == true ? local.public_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
  route_table_id         = each.value.route_table_id
}


#############################################################
# Private Route Tables
#############################################################
resource "aws_route_table" "private" {
  provider = aws.account
  for_each = local.private_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-private-route-table", replace(local.full_vpc_name, data.aws_region.region.name, each.value.availability_zone))
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "private" {
  provider       = aws.account
  for_each       = local.private_route_tables
  subnet_id      = element([for s in local.private_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "private_nat_gateway" {
  provider               = aws.account
  for_each               = var.internet_enabled == true ? local.private_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element([for v in aws_nat_gateway.ngw : v.id if v.tags.availability_zone == each.value.availability_zone], 0)
  route_table_id         = each.value.route_table_id
}


#############################################################
# Data Route Tables
#############################################################
resource "aws_route_table" "data" {
  provider = aws.account
  for_each = local.data_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-data-route-table", replace(local.full_vpc_name, data.aws_region.region.name, each.value.availability_zone))
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "data" {
  provider       = aws.account
  for_each       = local.data_route_tables
  subnet_id      = element([for s in local.data_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "data_nat_gateway" {
  provider               = aws.account
  for_each               = var.internet_enabled == true ? local.data_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element([for v in aws_nat_gateway.ngw : v.id if v.tags.availability_zone == each.value.availability_zone], 0)
  route_table_id         = each.value.route_table_id
}


#############################################################
# Transit Gateway routes
#############################################################
resource "aws_route_table" "transit" {
  provider = aws.account
  for_each = local.transit_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-transit-route-table", replace(local.full_vpc_name, data.aws_region.region.name, each.value.availability_zone))
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "transit" {
  provider       = aws.account
  for_each       = local.transit_route_tables
  subnet_id      = element([for s in local.transit_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "transit" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.transit_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}



###############################################################################
# Network Access Control Lists (NACLs)
###############################################################################
#############################################################
# Public NACL
#############################################################
resource "aws_network_acl" "public" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.public_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-public-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Public NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "public_inbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_inbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 105
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_inbound_ephemeral_udp" {
  provider       = aws.account
  count          = var.enable_udp == true ? 1 : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = 106
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_inbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block])) : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block]))), count.index)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


##########################################
# Public NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "public_outbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_outbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_outbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 105
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_outbound_ephemeral_udp" {
  provider       = aws.account
  count          = var.enable_udp == true ? 1 : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = 106
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_outbound_application" {
  provider       = aws.account
  for_each       = local.public_nacl_application
  network_acl_id = aws_network_acl.public.id
  rule_number    = element(range(200, 200 + length(local.public_nacl_application)), index(keys(local.public_nacl_application), each.key))
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "public_outbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block])) : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block]))), count.index)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


#############################################################
# Private NACL
#############################################################
resource "aws_network_acl" "private" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.private_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-private-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Private NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_inbound_ephemeral_udp" {
  provider       = aws.account
  count          = var.enable_udp == true ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 101
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_inbound_application" {
  provider       = aws.account
  for_each       = local.private_nacl_application
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(200, 200 + length(local.private_nacl_application)), index(keys(local.private_nacl_application), each.key))
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "private_inbound_private" {
  provider       = aws.account
  for_each       = local.private_subnets
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(310, 310 + length(local.private_subnets)), index(keys(local.private_subnets), each.key))
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "private_inbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block])) : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block]))), count.index)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}

##########################################
# Private NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "private_outbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "private_outbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "private_outbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 105
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_outbound_ephemeral_udp" {
  provider       = aws.account
  count          = var.enable_udp == true ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 106
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_outbound_database" {
  provider       = aws.account
  for_each       = local.private_nacl_database
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(200, 200 + length(local.private_nacl_database)), index(keys(local.private_nacl_database), each.key))
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}
resource "aws_network_acl_rule" "private_outbound_private" {
  provider       = aws.account
  for_each       = local.private_subnets
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(310, 310 + length(local.private_subnets)), index(keys(local.private_subnets), each.key))
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "private_outbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block])) : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block]))), count.index)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


#############################################################
# Data NACL
#############################################################
resource "aws_network_acl" "data" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.data_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-data-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Data NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "data_inbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_inbound_private" {
  provider       = aws.account
  for_each       = local.data_nacl_database
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(200, 200 + length(local.data_nacl_database)), index(keys(local.data_nacl_database), each.key))
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "data_inbound_data" {
  provider       = aws.account
  for_each       = local.data_subnets
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(310, 310 + length(local.data_subnets)), index(keys(local.data_subnets), each.key))
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "data_inbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block])) : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block]))), count.index)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


##########################################
# Data NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "data_outbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "data_outbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "data_outbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 105
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_outbound_data" {
  provider       = aws.account
  for_each       = local.data_subnets
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(310, 310 + length(local.data_subnets)), index(keys(local.data_subnets), each.key))
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "data_outbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block])) : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block]))), count.index)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


#############################################################
# Transit NACL
#############################################################
resource "aws_network_acl" "transit" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.transit_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-transit-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Transit NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "transit_inbound" {
  provider       = aws.account
  network_acl_id = aws_network_acl.transit.id
  rule_number    = 100
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = -1
  to_port        = -1
}

##########################################
# Transit NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "transit_outbound" {
  provider       = aws.account
  network_acl_id = aws_network_acl.transit.id
  rule_number    = 100
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = -1
  to_port        = -1
}


###############################################################################
# VPC Endpoints
###############################################################################
############################################################
# Gateway Endpoints
############################################################
#########################################
# S3 Endpoint
#########################################
resource "aws_vpc_endpoint" "s3" {
  provider     = aws.account
  count        = contains(local.vpc_endpoints, "s3") == true ? 1 : 0
  vpc_id       = aws_vpc.vpc.id
  service_name = format("com.amazonaws.%s.s3", data.aws_region.region.name)

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-s3-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  provider        = aws.account
  for_each        = contains(local.vpc_endpoints, "s3") == true ? merge(local.public_route_tables) : {}
  route_table_id  = each.value.route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

#########################################
# DynamoDB Endpoint
#########################################
resource "aws_vpc_endpoint" "dynamodb" {
  provider     = aws.account
  count        = contains(local.vpc_endpoints, "dynamodb") == true ? 1 : 0
  vpc_id       = aws_vpc.vpc.id
  service_name = format("com.amazonaws.%s.dynamodb", data.aws_region.region.name)

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-dynamodb-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  provider        = aws.account
  for_each        = contains(local.vpc_endpoints, "dynamodb") == true ? merge(local.public_route_tables) : {}
  route_table_id  = each.value.route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
}


############################################################
# Interface Endpoints
############################################################
#########################################
# Cloudwatch Endpoints
#########################################
resource "aws_vpc_endpoint" "cloudwatch" {
  provider            = aws.account
  count               = contains(local.vpc_endpoints, "cloudwatch") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.logs", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id]
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-cloudwatch-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# EC2 Endpoints
#########################################
resource "aws_vpc_endpoint" "ec2" {
  provider            = aws.account
  count               = contains(local.vpc_endpoints, "ec2") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ec2", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ec2-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint" "autoscaling" {
  provider            = aws.account
  count               = contains(local.vpc_endpoints, "autoscaling") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.autoscaling", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-autoscaling-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint" "ebs" {
  provider            = aws.account
  count               = contains(local.vpc_endpoints, "ebs") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ebs", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ebs-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# ECR Endpoints
#########################################
resource "aws_vpc_endpoint" "ecr_dkr" {
  provider            = aws.account
  count               = contains(local.vpc_endpoints, "ecs") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ecr.dkr", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ecrdkr-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint" "ecr_api" {
  provider            = aws.account
  count               = contains(local.vpc_endpoints, "ecs") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ecr.api", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ecrapi-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}


#########################################
# App Mesh Endpoints
#########################################
resource "aws_vpc_endpoint" "appmesh" {
  provider            = aws.account
  count               = contains(local.enabled_vpc_endpoints, "appmesh") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.appmesh-envoy-management", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-appmesh-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# Private Certificate Authority Endpoints
#########################################
resource "aws_vpc_endpoint" "private_ca" {
  provider            = aws.account
  count               = contains(local.enabled_vpc_endpoints, "privateca") == true ? 1 : 0
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.acm-pca", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-privateca-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# Interface Endpoint Security Group
#########################################
resource "aws_security_group" "endpoints" {
  provider    = aws.account
  count       = length(setintersection(var.enabled_vpc_endpoints, local.interface_endpoints)) > 0 ? 1 : 0
  name        = format("%s-vpc-endpoints", local.full_vpc_name)
  description = "Controls access to VPC Interface Endpoints"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-vpc-endpoints", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_security_group_rule" "ingress_https" {
  provider          = aws.account
  count             = length(setintersection(var.enabled_vpc_endpoints, local.interface_endpoints)) > 0 ? 1 : 0
  type              = "ingress"
  description       = "inbound 443 from private subnets"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = flatten([[for s in local.private_subnets : s.cidr_block], [for s in local.data_subnets : s.cidr_block]])
  security_group_id = aws_security_group.endpoints[0].id
}


###############################################################################
# VPC FLOW LOGS
###############################################################################
resource "aws_iam_role" "vpc_flow_log_role" {
  provider           = aws.account
  count              = var.enable_flow_logs == true ? 1 : 0
  name               = format("%s-%s-vpc-flow-log-role", data.aws_region.region.name, local.full_vpc_name)
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_log_assume[0].json
}

data "aws_iam_policy_document" "vpc_flow_log_assume" {
  provider = aws.account
  count    = var.enable_flow_logs == true ? 1 : 0
  statement {
    sid     = "FlowLogTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  provider = aws.account
  count    = var.enable_flow_logs == true ? 1 : 0
  name     = format("%s-vpc-flow-log-policy", local.full_vpc_name)
  role     = aws_iam_role.vpc_flow_log_role[0].id
  policy   = data.aws_iam_policy_document.vpc_flow_log_policy[0].json
}

data "aws_iam_policy_document" "vpc_flow_log_policy" {
  provider = aws.account
  count    = var.enable_flow_logs == true ? 1 : 0
  statement {
    sid       = "AllowCreateLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    resources = ["*"]
  }
}

resource "aws_flow_log" "vpc_flow_log" {
  provider        = aws.account
  count           = var.enable_flow_logs == true ? 1 : 0
  log_destination = aws_cloudwatch_log_group.flow_log_group[0].arn
  iam_role_arn    = aws_iam_role.vpc_flow_log_role[0].arn
  vpc_id          = aws_vpc.vpc.id
  traffic_type    = "ALL"
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  provider          = aws.account
  count             = var.enable_flow_logs == true ? 1 : 0
  name              = format("/aws/vpc-flow-logs/%s", local.full_vpc_name)
  retention_in_days = 30
  kms_key_id        = data.aws_kms_key.logs[0].arn
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

###############################################################################
# Service Discovery & DNS
###############################################################################
resource "aws_service_discovery_private_dns_namespace" "namespace" {
  provider    = aws.account
  for_each    = var.namespaces != null ? toset(flatten([var.namespaces])) : []
  name        = each.value
  description = format("private namespace for the %s", local.full_vpc_name)
  vpc         = aws_vpc.vpc.id
}


###############################################################################
# Managed Prefix lists
###############################################################################
resource "aws_ec2_managed_prefix_list" "prefix_lists" {
  provider       = aws.account
  for_each       = local.prefix_lists
  name           = format("%s-%s-prefix-list", local.full_vpc_name, each.value.layer)
  address_family = "IPv4"
  max_entries    = length(each.value.cidrs)

  dynamic "entry" {
    for_each = each.value.cidrs
    content {
      cidr        = entry.value
      description = format("Truly %s %s Prefix List", local.full_vpc_name, title(replace(each.key, "_", " ")))
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment,
      layer       = each.value.layer
      service     = var.vpc_name
    }
  )
}
