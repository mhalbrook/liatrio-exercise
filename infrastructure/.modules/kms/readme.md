# Terraform Library Module | KMS Key

**Current Version**: v1.0

This module creates a KMS Key for encryption fo AWS Resources. The module may be configured to create identical KMS Keys in up to three AWS Regions. Additionally, the module supports configuring a custom Key Policy for the KMS Key.


## Known Issues
There are no known issues with this module.


## Providers
From a root module, set a provider for the account in which to build the KMS Key. When calling this Library module, set the provider equal to *aws.account*.

Additionally, set a provider for each additional AWS Region within the same AWS Account and, when calling this Library module, set the providers equal to *aws.secondary* and *aws.tertiary*. This provider allows the module to provision additional KMS Keys in the other AWS Regions. If a multi-region key is not being provisioned, these providers are still required, however, the provider swill not be used to provision any resources, therefore, any valid provider may be used.
## Features 

### Multi-Region
This module supports provisioning KMS Keys in up to three AWS Regions. This feature is enabled when the *replication_region_count* variable is set to a value greater than *1*.     

When the *replication_region_count* variable is set to *2*, two KMS Keys will be provisioned. The first key will be provisioned to the AWS Region associated with the *aws.account* provider, while the second key will be provisioned to the AWS Region associated with the *aws.secondary* provider.

When the *replication_region_count* variable is set to *3*, three KMS Keys will be provisioned. The first key will be provisioned to the AWS Region associated with the *aws.account* provider, the second key will be provisioned to the AWS Region associated with the *aws.secondary* provider, and the third key will be provisioned to the AWS Region associated with the *aws.tertiary* provider.     
&nbsp;


### Custom Key Policy
This module supports the configuration of a custom Key Policy for the provisioned KMS Key. This feature is enabled when a valid JSON KMS Key Policy is provided to the *key_policy* variable.

This feature is not available when the KMS Key is configured to encrypt S3 Buckets that capture Access Logs from Elastic Load Balancers or S3 Buckets (i.e. the Logging Key feature is enabled).    
&nbsp;


### Logging Key
This module supports configuring the KMS Key to be used for encryption fo S3 Buckets which collect Access Logs from Elastic Load Balancers and/or S3 Buckets. This feature is enabled when the *is_logging_key* variable is set to *true*. 

When enabled, a Key Policy enabling log collection functions is attached to the KMS Key. This policy overrides any Custom Key Policy provided to the module.    
&nbsp;



## Dependencies
This module has no dependencies.



## Examples
### Example with only *required* variables
        module "kms" {
          source      = "./modules/kms"
          environment = "prod"
          service     = "example-service"
          suffix      = "es"

          providers = {
            aws.account     = aws.region1
            aws.secondary   = aws.region2
            aws.tertiary    = aws.region3
          }
        }

### Example with *all* variables
        module "kms" {
          source                     = "./modules/kms"
          environment                = "prod"
          service                    = "example-service"
          suffix                     = "es"
          replication_region_count   = 3 
          key_policy                 = data.aws_iam_policy_document.key_policy.json
          is_logging_key             = true

          providers = {
            aws.account     = aws.region1
            aws.secondary   = aws.region2
            aws.tertiary    = aws.region3
          }
        }       



## Variables

### Required Variables
* **environment** *string* = Environment that the KMS Key will support. 
    * Valid options are 'dev', 'staging', 'prod', or 'core'.
* **service** *string* = Friendly name of the service or resource that the KMS Key will be used to encrypt.
    * The module will use this value to create a human-readable description of the KMS Key
* **suffix** *string* = Abbreviation of the service or resource that the KMS Key will be used to encrypt.


### Optional Variables

#### Multi-Region 
* **replication_region_count** *number* = The number of AWS Regions in which to provision KMS Keys.
    * Defaults to *1* AWS Region.

#### Custom Key Policy
* **key_policy** *string* = JSON-formatted Key Policy to apply to the KMS Key.    
    * This argument is ignored when *is_logging_key* is set to *true*.

#### Logging Key
* **is_logging_key** = Sets whether the KMS Key is used to encrypt S3 Buckets that collect Access Logs from Load Balancers and/or S3 Buckets.
    * Defaults to *false*.


## Outputs

### KMS Key Outputs
KMS Key Outputs are presented as Maps to allow for simplified output referencing when multi-region keys are provisioned. In all cases, the map *key* is the AWS Region in which the KMS Key has been provisioned.

For example, if the module provisions two KMS Keys, one in us-east-1 and another in us-west-2, the arn of the KMS Key in the us-east-1 region may be referenced via *module.example.key_arn["us-east-1"]*, while the KMS Key in the us-west-2 region may be referenced via *module.example.key_arn["us-west-2"]*.

* **key_name** = Friendly name of the KMS Key.
* **key_alias** = Alias of the KMS Key.
    * All KMS Key Aliases begin with *alias/*.
* **key_arn** = ARN of the KMS Key.
* **key_id** = Name of the KMS Key.
