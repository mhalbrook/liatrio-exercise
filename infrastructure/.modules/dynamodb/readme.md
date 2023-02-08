# Terraform Library Module | DynamoDB Table 

**Current Version**: v1.0

This module creates an encrypted, provisioned or pay-per-request DynamoDB Table and allows for creation of Global Secondary Indices and/or Local Secondary Indices. Additionally, the module may be configured to provision a an IAM Role with Read and/or Write access to the Table.


## Known Issues
The following are known issues within the DynamoDB Table Library Module. These issues are primarily driven by the behavior of either Terraform or the AWS resources managed by the module.

1. Terraform fails to update the TTL configuration of an existing DynamoDB Table.

  * **Cause:** AWS does not support changing the configuration of TTL once it is set on a DynamoDB Table. This included disabling TTL and/or changing the name of the *attribute* used for TTL. However, AWS does support *enabling* TTL on an existing DynamoDB Table.
  * **Workaround:** Destroy and re-create the DynamoDB Table.

2. Terraform fails to update the Secondary Index configuration of an existing DynamoDB Table.

  * **Cause:** AWS does not support changing the configuration of Secondary Indices of existing DynamoDB tables. This includes both the Local and Global Secondary Indices.
  * **Workaround:** Destroy and re-create the DynamoDB Table.

## Providers
From a root module, set a provider for the account in which to build the resources. When calling this Library module, set the provider equal to 'aws.account'.


## Features 
### Provisioned Billing Mode
This module supports provisioning a DynamoDB Table with a *Provisioned* Billing Mode. This feature is enabled when the *billing_mode* variable is set to *provisioned*.

By default, read or write capacity for the Table is NOT set and billing is consumption-based, allowing for the management of tables with unknown or unpredictable throughput requirements. However, when throughput requirements are known and predictable, Provisioned Mode can be enabled to configure flat, consistent billing for DynamoDB based on the Maximum Read and Write throughput required for the Table. When this feature is enabled, the *read_capacity* and *write_capacity* variables are required.  
&nbsp;


### Time To Live
This module supports provisioning a DynamoDB Table with Time To Live (TTL) enabled. When TTL is enabled, a specialize attribute is added to the DynamoDB table as the *TTL Attribute*. This attribute may be populated with a timestamp in [Unix Epoch Time Format](https://en.wikipedia.org/wiki/Unix_time). Once the specified time is reached, the item will be deleted from the DynamoDB table. This feature is enabled when the *enable_ttl* variable is set to *true*.  
&nbsp;


### Read and Write Roles
This module may be configured to provision IAM Roles for *Read* and/or *Write* access to the DynamoDB Table. This simplifies DynamoDB Table access in certain scenarios by generating dedicated IAM Roles that may be *assumed* when taking actions against the DynamoDB Table. This cna be especially useful when the DynamoDB Table needs to be Read or Written to cross-account.

This feature is enabled by providing a valid list of AWS Account IDs and/or IAM Roles to the *trusted_entities_read* and/or *trusted_entities_write* variables. The entities provided will be permitted to assume the IAM Roles for Read and Write access, respectively.  
&nbsp; 


### Stream Views
This module supports the customization of the DynamoDB Stream View. Stream Views capture data changes within the DynamoDB table, serving as a change log for your DynamoDB table. By default, Stream Views are configured to capture the entire detail of the Item, or *image*, as it appeared before and after it was modified. This feature may be customized by providing one of the following values to the *stream_view_type* variable.

  * **KEYS_ONLY** = Only capture changes to attributes configured as *hash* or *range* keys.
  * **NEW_IMAGE** = Capture the entire Item, as it appears after being modified.
  * **OLD_IMAGE** = Capture the entire Item, as it appeared before being modified.


### Secondary Indices 
This module supports the configuration of a Local and/or Global Secondary Index for the DynamoDB Table. Secondary Indices are sets of *range* and/or *hash* keys that can be used to query the table more easily. These indices may be queried, instead of the primary *hash* and *range* keys, to return different sets of data, which may improve performance when specific queries are frequently run and parsed.

This feature is enabled by providing a valid map of the Local and/or Global Secondary Index to the *local_secondary_index* and/or *global_secondary_index* variables, respectively.  
&nbsp; 




## Dependencies
The following resources are always required for the module:

    * KMS Key (used to encrypt the DynamoDB Table)




## Examples
### Example with only *required* variables
    module "dynamodb" {
      source              = "../modules/dynamodb"
      environment         = "prod"
      table_name          = "example"
      hash_key            = {"hash" = "S"}
      kms_key_arn         = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      data_classification = "internal confidential"

      providers = {
        aws.account       = aws.example
      }
    }


### Example with *all* variables
    module "dynamodb" {
      source                     = "../modules/dynamodb"
      project                    = "example-project"
      environment                = "prod"
      table_name                 = "example"
      billing_mode               = "PROVISIONED"
      read_capacity              = 500
      write_capacity             = 1000
      hash_key                   = {"hash" = "S"}
      range_key                  = {"range" = "N"}
      kms_key_arn                = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      data_classification        = "internal confidential"
      enable_ttl                 = true 
      ttl_attribute_name         = "expiration_dttm"
      stream_view_type           = "NEW_IMAGE"
      trusted_entities_read_only = ["aws:arn:iam::xxxxxxxx:role/example", "aws:arn:iam::xxxxxxxx:root"]
      trusted_entities_write     = ["aws:arn:iam::xxxxxxxx:role/example", "aws:arn:iam::xxxxxxxx:root"]
      local_secondary_index      = {
        example-lsi = {
          range_key          = "range2"
          range_key_type     = "S"
          projection_type    = "INCLUDE"
          non_key_attributes = ["attribute1", "attribute2"]
        }
      }
      global_secondary_index     = {
        example-gsi = {
          range_key          = "range2"
          range_key_type     = "S"
          hash_key           = "hash2"
          hash_key_type      = "N"
          projection_type    = "INCLUDE"
          non_key_attributes = ["attribute1", "attribute2"]
        }
      }

      providers = {
        aws.account       = aws.example
      }
    }



## Variables

### Required Variables
* **environment** *string* = The environment in which to provision resources. 
    * Valid options are 'dev', 'staging', 'prod', or 'core'.
* **table_name** *string* = The display name for the DynamoDB table being provisioned.
    * Final Table Name will be created by appending the *table_name* to the Friendly Name of the AWS Account and the *environment*
* **hash_key** *map(string)* = A map including the name of the attribute to be used as the hash (partition) key & the attribute type ('S', 'B', or 'N'). *i.e. {"attributeName = attributeType}*
* **kms_key_arn** *string* = The ARN of the KMS key used to encrypt the DynamoDB table. Should be a Customer Managed Key (CMK).
* **data_classification** *string* = The Data Classification for the DyanmoDB table. Valid options are 'confidential', 'internal_confidential', or 'public'.


### Optional Variables
* **project** *string* = The project that the AWS resources will support.
    * May be used to override the Table Name schema by replacing the Name of the AWS Account.
* **range_key** *map(string)*= A map including the name of the attribute to be used as the range (sort) key & the attribute type ('S', 'B', or 'N'). *i.e. {"attributeName" = "attributeType"}* 


#### Provisioned Billing Mode
This argument is optional, however the addition of a range key to an existing table **requires resource replacement**.

* **billing_mode** *string* = Sets whether to bill based on a PAY_PER_REQUEST model or a PROVISIONED model. Defaults to PAY_PER_REQUEST
    * *In a Provisioned model, max read & write capacity for the table is set and billing is flat based on the capacity configuration. If throughput requirements are well known and predictable, this model can be cost effective.*
    * *In a PAY_PER_REQUEST model, max read or write capacity for the table is NOT set and billing is consumption-based. This model allows for the management of tables with unknown or unpredictable throughput requirements.*
* **write_capacity** *number* = The number of Write Capacity Units for the table. Only applicable when billing_mode is set to PROVISIONED.
    * *One write capacity unit represents one write per second for an item up to 1 KB in size. The total number of write capacity units required depends on the item size. For example, if your item size is 2 KB, you require 2 write capacity units to sustain one write request per second or 4 write capacity units for a transactional write request.*
* **read_capacity** *number* = The number of Read Capacity Units for the table. Only applicable when billing_mode is set to PROVISIONED.
    * *One read request unit represents one *strongly* *consistent read request, or two *eventually* *consistent read requests, for an item up to 4 KB in size. The total number of read request units required depends on the item size, and whether you want an eventually consistent or strongly consistent read. For example, if your item size is 8 KB, you require 2 read request units to sustain one strongly consistent read, 1 read request unit if you choose eventually consistent reads, or 4 read request units for a transactional read request.*



#### Time To Live
* **enable_ttl** *boolean* = Sets whether to enable Time-To-Live (TTL) on items within the table.
    * Defaults to *false*
    * When TTL is enabled, a specialize attribute name is added to the DynamoDB table. This attribute may be populated with a timestamp in Unix Epoch Time Format (https://en.wikipedia.org/wiki/Unix_time). Once the specified time is reached, the item will be deleted from the DynamoDB table.
* **ttl_attribute_name** *string* = Friendly name of the Attribute to be used as for TTL.
    * Defaults to *expirationDate*.


#### Read and Write Roles
* **trusted_entities_read_only** *list* = A list of AWS Account IDs and/or IAM Roles that are permitted to perform read-only actions against the DynamoDB table. If this variable is omitted, a read-only role is not created.
    * Entities must be created **before** being referenced by module. If the AWS Account or IAM Role does not exist, an error will be received when attempting to create the read-only role
    * Listed entities must be within an AWS Organization. For example, an IAM Role in a third-party vendor's AWS Account may not be referenced.
    * IAM Role ARNs, AWS Account ARNs, AWS Account IDs, or IAM Role Names may be provided within the list. List elements may be of the same type or a mixture of the previously-mentioned entity types.
      * *If provided an AWS Account ID, the module will normalize the element by converting it to an AWS Account ARN.* 
      * *If provided an IAM Role Name, the module will normalize the element by converting it to an IAM Role ARN, assuming the IAM Role exists in the same account as the DynamoDB table. Providing an IAM Role ARN for a role in a different AWS account will allow cross-account, read-only permissions to the specified role*
* **trusted_entities_write** *list* = A list of AWS Account IDs and/or IAM Roles that are permitted to perform write actions against the DynamoDB table. If this variable is omitted, a write role is not created.
  * Entities must be created **before** being referenced by module. If the AWS Account or IAM Role does not exist, an error will be received when attempting to create the write role
  * Listed entities must be within an AWS Organization. For example, an IAM Role in a third-party vendor's AWS Account may not be referenced.
  * IAM Role ARNs, AWS Account ARNs, AWS Account IDs, or IAM Role Names may be provided within the list. List elements may be of the same type or a mixture of the previously-mentioned entity types.
    * *If provided an AWS Account ID, the module will normalize the element by converting it to an AWS Account ARN.* 
    * *If provided an IAM Role Name, the module will normalize the element by converting it to an IAM Role ARN, assuming the IAM Role exists in the same account as the DynamoDB table. Providing an IAM Role ARN for a role in a different AWS account will allow cross-account, write permissions to the specified role*


#### Stream Views
* **stream_view_type** *string* = Sets what information is written to the table's *Stream view*. Valid options are 'KEYS_ONLY', 'NEW_IMAGE', 'OLD_IMAGE', or 'NEW_AND_OLD_IMAGES'. Defaults to 'NEW_AND_OLD_IMAGES'.
    * A Stream View captures data changes within the DynamoDB table. This serves as an easily-configured change log for your DynamoDB table. Stream data is retained for 24 hours.
    * Stream views are enabled by default and cannot be disabled via this module.


#### Secondary Indices    
* **local_secondary_index** *map(object)* = A map of Local Secondary Indices (LSI) to set within the table and the associated arguments required to describe the LSIs. Adding an LSI to an existing table **requires resource replacement**.
    * LSIs are secondary range (sort) keys that may be used to query the table more easily. The following arguments are required if LSI is not null:
        * **range_key** = The name of the attribute to use as the range (sort) key
        * **range_key_type** = The attribute type of the range (sort) key ('S', 'B', or 'N')
        * **projection_type** = Sets which attributes to project in the LSI. Projected attributes may be queried using the LSI. Valid options are 'ALL' (projects all attributes), 'KEYS_ONLY' (projects primary hash and range keys), or 'INCLUDE' (projects attributes explicitly defined in the *non_key_attributes* argument)
        * **non_key_attributes** = List of specific attributes to be projected in the LSI. Only valid when *projection_type* is set to INCLUDE
* **global_secondary_index** *map(object)* = A map of Global Secondary Indices (GSI) to set within the table and the associated arguments required to describe the GSIs. Adding a GSI to an existing table **requires resource replacement**.
    * GSIs are sets of secondary hash (partition) and range (sort) keys that may be used to query the table more easily. The following arguments are required if GSI is not null:
        * **hash_key** = The name of the attribute to use as the hash (partition) key
        * **hash_key_type** = The attribute type of the hash (partition) key ('S', 'B', or 'N')
        * **range_key** = The name of the attribute to use as the range (sort) key (can be set to null)
        * **range_key_type** = The attribute type of the range (sort) key ('S', 'B', or 'N') (can be set to null)
        * **projection_type** = Sets which attributes to project in the LSI. Projected attributes may be queried using the LSI. Valid options are 'ALL' (projects all attributes), 'KEYS_ONLY' (projects primary hash and range keys), or 'INCLUDE' (projects attributes explicitly defined in the *non_key_attributes* argument)
        * **non_key_attributes** = List of specific attributes to be projected in the LSI. Only valid when *projection_type* is set to INCLUDE
        * **write_capacity** = The number of Write Capacity Units for the queries using the GSI. Only applicable when billing_mode is set to PROVISIONED.
        * **read_capacity** = The number of Read Capacity Units for the queries using the GSI. Only applicable when billing_mode is set to PROVISIONED.



## Outputs

### DynamoDB Table Outputs
* **table_name** = The friendly name of the DynamoDB table
* **table_arn** = The ARN of the DynamoDB table
* **table_hash_key** = The attribute used as the hash (partition) key
* **table_range_key** = The attribute used as the range (sort) key
* **stream_arn** = The ARN of the DynamoDB table Stream
* **stream_label** = The timestamp label for the DynamoDB table Stream
* **stream_id** = The unique identifier for the DynamoDB table Stream *(accountID+tableName+streamLabel)*

### IAM Role Outputs
* **Read Only Role Outputs**
  * **read_only_role_arn** = The ARN of the IAM Role that if permitted to perform read-only actions against the DynamoDB table
  * **read_only_role_id** = The ID of the IAM Role that if permitted to perform read-only actions against the DynamoDB table
  * **read_only_role_name** = The friendly Name of the IAM Role that if permitted to perform read-only actions against the DynamoDB table
  * **read_only_role_unique_id** = The Unique ID of the IAM Role that if permitted to perform read-only actions against the DynamoDB table
* **Write Role Outputs**
  * **write_role_arn** = The ARN of the IAM Role that if permitted to perform write actions against the DynamoDB table
  * **write_role_id** = The ID of the IAM Role that if permitted to perform write actions against the DynamoDB table
  * **write_role_name** = The friendly Name of the IAM Role that if permitted to perform write actions against the DynamoDB table
  * **write_role_unique_id** = The Unique ID of the IAM Role that if permitted to perform write actions against the DynamoDB table
