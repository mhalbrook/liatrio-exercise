# Terraform Library Module | VPC

**Current Version**: v1.0

This module creates an AWS VPC with four network layers: Public, Private, Data, and Transit. Each subnet is configured with default routes and NACL Rules required for all VPCs. 

## Known Issues
There are no known issues with this module.

## Providers
From a root module, set a provider for the account in which to build the App Mesh. When calling this Library module, set the provider equal to *aws.account*.  
&nbsp;

## Features 

### Subnet Sizing
This module is designed to create VPC Subnets with a /20 or /24 subnet mask. When generating VPC that may have a high number of running endpoints within the subnets, /20 subnets should be generated.

The subnet sizes are configured by providing a valid number (20 or 24) to the *subnet_mask_slash_notation* variable.

If /20 subnets are provisioned, the *public* and *transit* subnets are created as /24 subnets inside the first available /20 subnet. This allows for the maximization of subnets available to the *private* and *data* layers where larger numbers of endpoints need to be accommodated. 

*Note* that this module is optimized when the *vpc_cidr* is configured as a /16 subnet.   
&nbsp;

### Internet Connectivity
By default, the module configures the VPC to allow inbound internet connections to the VPC's Public Subnet. However, the VPC may be configured to disable internet access. This feature may be useful for creating VPCs that hosts services used by employees, but not by clients or other external stakeholders.

Internet access is disabled by setting the *internet_enabled* variable to false. By default, this variable is set to true.  
&nbsp;

### Multiple Availability Zones
This module supports configuring multiple Availability Zones within the VPC. When additional Availability Zones are configured, the module generates a Public, Private, Data, and Transit Subnet within each additional Availability Zone with default Routes and NACL Rules. 

By default, the module will provision a VPC with **two** Availability Zones. Additional Availability Zones may be added by setting the *availability_zone_count* variable to a number greater than *two*.  
&nbsp;

### Transit Gateway Attachments
This module supports attaching the VPC to an existing Transit Gateway. This feature is enabled by providing a valid Transit gateway ID to the *transit_gateway_id* variable.  
&nbsp;

### VPC Endpoints
This module supports configuring the VPC with multiple VPC Endpoints to allow private connections to AWS Services. By default, VPC Endpoints for the following AWS Services are always created:

  * S3
  * DynamoDB
  * Cloudwatch 
  * EC2
  * Autoscaling 
  * EBS
  * ECR
  * ECS

Additionally, VPC Endpoints for the following services may be provisioned. This feature is enabled when a valid list of VPC Endpoints is provided to the *enabled_vpc_endpoints* variable.

  * AppMesh (as appmesh)
  * Private Certificate Authority (as privateca)


### Application Connectivity
This module supports configuring NACL rules to allow connectivity between the VPC's Public and Private Subnets in order to enable connectivity between the Public Layer and applications that will run within the VPC. This feature is enabled by provide a valid list of ports to the *application_ports* variable.

When enabled, outbound rules will be generated within the Public Subnet's NACL to allow connectivity to the Private Subnets on the specified ports. Additionally, inbound rules will be generated within the Private Subnet's NACL to allow connectivity from the Public Subnets on the specified ports.  
&nbsp;
### Database Connectivity
This module supports configuring NACL rules to allow connectivity between the VPC's Private and Data Subnets in order to enable connectivity between application instances and databases instances that will run within the VPC. This feature is enabled by provide a valid list of ports to the *database_ports* variable.

When enabled, a outbound rules will be generated within the Private Subnet's NACL to allow connectivity to the Data Subnets on the specified ports. Additionally, inbound rules will be generated within the Data Subnet's NACL to allow connectivity from the Private Subnets on the specified ports.  
&nbsp;

### Namespaces
This module supports provisioning a private CloudMap Namespace associated with the VPC. This feature is enabled when a valid Namespace or List of Namespaces are provided to the *namespaces* variable.

CloudMap is an AWS Service that provides an API Layer on top fo a Private Route53 Hosted Zone. AWS Services, such as ECS, may be directly integrated into the Namespace for Service Discovery. Additionally, other services may be configured to register instances with the CloudMap Namespace allowing for easy management and lookup of private DNS records.  
&nbsp;

### UDP 
This module supports configuring NACL rules to allow UDP connectivity on ephemeral ports. This feature is enabled when the *enable_udp* variable is set to *true*. 

By default, ephemeral ports are only whitelisted for TCP connections, however, when *enable_udp* is set to *true* ephemeral ports are whitelisted for UDP connections into the **public** and **private** subnets. 
&nbsp;

### smtp 
This module supports configuring NACL rules to allow SMTP (email) connectivity through the public and private subnet layers. This feature is enabled when the *enable_smtp* variable is set to *true*.  
&nbsp;

### ICMP 
This module supports configuring NACL rules to allow ICMP (ping) connectivity from Local networks. This feature is enabled when the *enable_icmp* variable is set to *true*. 

Note that, in order to establish ICMP connections, ICMP must be enabled for the VPC **AND** instances within the VPC must be configured to accept ICMP connections.  
&nbsp;


## Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules. 

The following resources are always required when provisioning a VPC with a Transit Gateway Attachment:

  * Transit Gateway



## Examples
### Example with only *required* variables
    module "vpc" {
      source      = "../modules/vpc"
      vpc_name    = "example-vpc-name"
      environment = "prod"
      vpc_cidr    = "10.1.0.0/16"

      providers = {
        aws.account = aws.example
      }
    }

### Example with *all* variables
    module "vpc" {
      source                     = "../modules/vpc"
      vpc_name                   = "example-vpc-name"
      environment                = "prod"
      availability_zone_count    = 3
      vpc_cidr                   = "10.1.0.0/16"
      subnet_mask_slash_notation = 20
      application_ports          = [8000, 9000]
      database_ports             = [1433, 3306]
      enable_icmp                = true
      enable_udp                 = true
      enable_smtp                = true
      enabled_vpc_endpoints      = ["appmesh", "privateca"]
      transit_gateway_id         = "tgw-xxxxxxxxxxxxx"
      namespaces                 = ["example.private", "two.example.private"]

      providers = {
        aws.account = aws.example
      }
    }



## Variables

#### Required Variables
* **environment** *string* = Environment that the Virtual Gateway supports. 
    * Valid options are 'dev', 'staging', 'prod', or 'core'.
* **vpc_name** *string* = Friendly name for the VPC.
    * The full name of the VPC is created dynamically by appending the *environment* to the *vpc_name*.
* **vpc_cidr** *string* = CIDR of the VPC.
    * The VPC CIDR should utilize a subnet no smaller than 255.255.254.0 (/23) as the module generates subnets with 255.255.0.0 (/24) subnet masks.
      * It is recommended that the VPC CIDR utilize a 255.255.255.0 (/16) subnet mask.


#### Optional Variables

##### Multiple Availability Zones
* **availability_zone_count** *number* = Sets the number of Availability Zones to provision within the VPC.
    * Defaults to *two*.

##### Transit gateway Attachment
* **transit_gateway_id** *string* = ID of the Transit Gateway to which the VPC should be attached.

##### VPC Endpoints
* **enabled_vpc_endpoints** *list* = List of AWS Services for which VPC Endpoints should be provisioned.
  * Valid options are *appmesh* and *privateca*.
  * By default, VPC Endpoints are generated for S3, DynamoDB, Cloudwatch, EC2, Autoscaling, EBS, ECR, and ECS.

##### Application and Database Connectivity
* **database_ports** *list(number)* = A list of ports on which the databases running within the VPC listen.
* **application_ports** *list(number)* = A list of ports on which the applications running within the Private Subnet of the VPC listen.

##### Namespaces
* **namespaces** *string* of *list(string)* = Namespaces to which the VPC is associated
  * When associating the VPC with one Namespace, the Namespace may be provided as a string, otherwise a *list* of namespaces should be provided.

##### UDP
* **enable_udp** *boolean* = Sets whether to generate NACL rules allowing UDP traffic on ephemeral ports.
    * Defaults to *false*

##### SMTP
* **enable_smtp** *boolean* = Sets whether to generate NACL rules allowing SMTP traffic through the public and private subnet layers
    * Defaults to *false*

##### ICMP
* **enable_icmp** *boolean* = Sets whether to generate NACL rules allowing ICMP traffic from Local networks.
    * Defaults to *false*




## Outputs
#### VPC Outputs
* **vpc_name** = Friendly name of the VPC.
* **vpc_arn** = ARN of the VPC.
* **vpc_id** = ID of the VPC.
* **vpc_cidr** = CIDR Notation of the VPC.
* **availability_zones** = Name of the Availability Zones in which VPC resources are provisioned.


#### Internet Gateway Outputs
* **internet_gateway_arn** = ARN of the Internet Gateway attached to the VPC.
* **internet_gateway_id** = ID of the Internet Gateway attached to the VPC.

#### NAT Gateway Outputs
NAT Gateway Outputs are presented as lists as the module always provisions at least two NAT Gateways. List may include two or more elements, depending on how many Availability Zones are configured within the VPC.

* **nat_gateway_ids** = List of the IDs of NAT Gateways provisioned in the Public Subnets of the VPC.
* **nat_gateway_public_ips** = List of the Public IPv4 Addresses associated with the NAT Gateways.
* **nat_gateway_private_ips** = List of the Private IPv4 Addresses associated with the NAT Gateways.

#### Transit Gateway Outputs
* **transit_gateway_id** = ID of the Transit Gateway to which the VPC is attached.

#### Subnet Outputs
Subnet Outputs are presented as Maps where each key corresponds to a Subnet Layer (Public, Private, Data, or Transit) and the values are lists of attributes. Each list may include two or more elements, depending on how many Availability Zones are configured within the VPC.

* **subnet_ids** = Map of Lists of the IDs of the Subnets provisioned within the VPC.
* **subnet_cidrs** = Map of Lists of the CIDR Notation of the Subnets provisioned within the VPC.

##### Example
The below example illustrates how the Subnet Outputs are configured as well as an example Local Block that references the VPC Module's Private Subnet IDs.}

    subnet_ids = {
      public  = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
      private = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
      data    = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
      transit = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
    }

    locals {
      private_subnet_ids = module.vpc.subnet_ids["private"]
    }


#### Network Access Control List (NACL) Outputs
NACL Outputs are presented as Maps where each key corresponds to a Subnet Layer (Public, Private, Data, or Transit) and the values are strings.

* **nacl_arns** = Map of ARNs of the Network Access Control Lists attached to each subnet within the VPC.
* **nacl_ids** = Map of IDs of the Network Access Control Lists attached to each subnet within the VPC.

##### Example
The below example illustrates how the NACL Outputs are configured as well as an example Local Block that references the ID of the NACL attached to the VPC's Private Subnet.

    nacl_id = {
      public  = "acl-xxxxxxxxxxxxxxxxx"
      private = "acl-xxxxxxxxxxxxxxxxx"
      data    = "acl-xxxxxxxxxxxxxxxxx"
      transit = "acl-xxxxxxxxxxxxxxxxx"
    }

    locals {
      private_nacl_id = module.vpc.nacl_id["private"]
    }


#### Route Table Outputs
Route Table Outputs are presented as Maps where each key corresponds to a Subnet Layer (Public, Private, Data, or Transit) and the values are lists of attributes. Each list may include two or more elements, depending on how many Availability Zones are configured within the VPC.

* **route_table_arns** = Map of ARNs of the Route Tables attached to each subnet within the VPC.
* **route_table_ids** = Map of IDs of the Route Tables attached to each subnet within the VPC.

##### Example
The below example illustrates how the Route Table Outputs are configured as well as an example Local Block that references the IDs of the Route Tables attached to the VPC's Private Subnet.

    subnet_ids = {
      public  = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
      private = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
      data    = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
      transit = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
    }

    locals {
      private_route_table_ids = module.vpc.route_table_ids["private"]
    }


#### VPC Endpoint Security Group Outputs
* **vpc_endpoint_security_group_name** = Friendly name of the Security Group attached to VPC Endpoints.
* **vpc_endpoint_security_group_arn** = ARN of the Security Group attached to VPC Endpoints.
* **vpc_endpoint_security_group_id** = ID of the Security Group attached to VPC Endpoints.


#### Namespace Outputs
Namespace Outputs are presented as lists to in order to accommodate multiple Namespace associations. In many cases, each output will be a list with one element. 

* **namespace_name** = Friendly Name of the Namespace(s) associated with the VPC
* **namespace_id** = ID of the Namespace(s) associated with the VPC

## Notes

### NACLs
This module generates NACLs with standard rules that align with a standard NACL Rule Numbering Schema. This schema is designed to make reading and managing NACLs simple by aligning NACL Rule Numbers to specific purposes. Below is an outline of the numbering schema.

  * **100** = Internet Connectivity (i.e. HTTP traffic in and out of the VPC)
  * **200** = Application and Database connectivity in support of the application(s) hosted within the VPC (i.e. Inbound connectivity from the private layer to the data layer on the database port)
  * **300** = Local, Intra-layer, and/or Campus connectivity (i.e. Inbound connectivity that applies to all hosts within the VPC, inbound and outbound access between multiple private subnets, or Database access from a VPN network)
  * **400** = Partner, Vendor, and/or Client connectivity (i.e. Outbound access to a client or partner's sFTP)
  * **500** = Internal Network Integrations (i.e. connectivity between the products)
  * **600** = ICMP Connectivity (i.e. Allowing ICMP connectivity from a VPN Network)
  * **1000** = Troubleshooting (i.e. Temporarily adding a rule to test remediation of an issue)

In some cases, the default NACL Rules generated by this module will need to be augmented to provide additional network connectivity. When configuring additional NACL Rules, the following rule numbers must be avoided as they are reserved by this module.

#### Public NACL
##### Inbound
  * **100-101**: HTTP/S traffic from the internet
  * **105**: Ephemeral TCP traffic from the internet
  * **106**: Ephemeral UDP traffic from the internet (if *enable_udp* = *true*)
  * **110 (+ number of public subnets)**: HTTPS traffic from Private Subnet to Internet
  * **115 (+ number of public subnets)**: HTTP traffic from Private Subnet to Internet
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

##### Outbound
  * **100-101**: HTTP/S traffic to the internet
  * **105**: Ephemeral TCP traffic from the internet
  * **106**: Ephemeral UDP traffic from the internet (if *enable_udp* = *true*)
  * **110 (+ number of public subnets x number of application ports)**: Application traffic to Private Subnet
  * **115 (+ number of public subnets)**: HTTP traffic from Private Subnet to Internet
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

#### Private NACL
##### Inbound
  * **100**: Ephemeral port traffic from the internet  
  * **200 (+ number of private subnets)**: Application traffic from the public subnets
  * **310 (+ number of private subnets)**: Traffic between the private subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

##### Outbound
  * **100-101**: HTTP/S traffic to the internet
  * **105**: Ephemeral port traffic to the internet
  * **200 (+ number of private subnets x number of database ports)**: Traffic to data subnets for database connectivity
  * **310 (+ number of private subnets)**: Traffic between the private subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

#### Data NACL
##### Inbound
  * **100**: Ephemeral port traffic from the internet  
  * **200 (+ number of private subnets x number of database ports)**: Traffic from private subnet for databases connectivity
  * **310 (+ number of private subnets)**: Traffic between the data subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

##### Outbound
  * **100-101**: HTTP/S traffic to the internet
  * **105**: Ephemeral port traffic to the internet
  * **200 (+ number of private subnets x number of database ports)**: Traffic to Data Subnet for database connectivity
  * **310 (+ number of data subnets)**: Traffic between the data subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)
