# Terraform Library Module | S3 Bucket

**Current Version**: v1.0

This module creates a private, KMS-Encrypted, S3 Bucket. The S3 Bucket may be configured with custom Lifecycle Rules, Bucket Policies, or CORS Rules. Additionally, the module may be configures to provision an additional S3 Bucket with a Replication Rule to sync data between the two S3 Buckets. Finally, the bucket may be configured to capture Elastic Load Balancer and S3 Access Logs.


## Known Issues
The following are known issues within the S3 Library Module. These issues are primarily driven by the behavior of either Terraform or the AWS resources managed by the module.

1. Terraform fails to provision a new S3 Bucket with replication.

  * **Cause:** Terraform requires replication configurations to be set within the S3 Bucket resource block. This creates a cycle issue where neither S3 Buckets may be completely provisioned as they both are dependent on the other S3 Bucket in order to complete their replication configuration. 
  * **Workaround:** Re-apply the Terraform module following the error. By the time the module is re-applied, the S3 Buckets will be in an *available* state and the configurations will be applied appropriately. Additionally, you may apply the module *without* replication, then configure replication and re-apply the module.


## Providers
From a root module, set a provider for the account in which to build the S3 Bucket. When calling this Library module, set the provider equal to *aws.account*.
Additionally, set a provider for an additional AWS Region within the same AWS Account and, when calling this Library module, set the provider equal to *aws.replication*. This provider allows the module to configure an additional S3 Bucket for object replication. If a replication S3 Bucket is not being provisioned, this provider is still required, however, the provider will not be used to provision any resources, therefore, any valid provider may be used.



## Features 

### Replication
This module supports provisioning a second S3 Bucket with a Replication Rule to sync data between the two S3 Buckets. This feature is enabled when the *replicate_bucket* variable is set to *true*. 

When replication is enabled, the *kms_key_arn_replication* variable is required.  
&nbsp;
 


### Bucket Policies
This module supports attaching a custom Bucket Policy via an external resource block. Bucket Policies may not be passed directly to this module as bucket policies must specify the S3 Bucket name in the *resources* section of the Bucket Policy, therefore, attempting to pass a custom policy to this module will result in a cycle error. Instead, a custom Bucket Policy may be attached to the S3 Bucket via the **aws_s3_bucket_policy** Terraform Resource. When a custom Bucket Policy is attached, the *default_bucket_policy* variable must be set to *false*.

When attaching a custom bucket policy, the *default_bucket_policy* variable must be set to *false*.

When the *default_bucket_policy* variable is set to *true*, a default Bucket Policy is attached to the S3 Bucket provisioned by the module. The default policy enforces SSL connections to the S3 Bucket. When attaching a custom Bucket Policy, the policy must include the following statement to enforce SSL connections, otherwise the S3 Bucket will be out-of-compliance with Standards:

      statement {
        sid       = "AllowSSLRequestsOnly"
        effect    = "Deny"
        actions   = ["s3:*"]
        resources = [*INSERT_BUCKET_NAME*]

        principals {
          type        = "*"
          identifiers = ["*"]
        }

        condition {
          test     = "Bool"
          variable = "aws:SecureTransport"
          values   = ["false"]
       }
      }


### Lifecycle Rules
This module supports the configuration of custom Lifecycle Rules to automate transitioning and/or expiring objects within the bucket. This feature is enabled when a valid Lifecycle Rule configuration is provided to the *lifecycle_rules* variable.

The *lifecycle_rules* variable requires a map where the *key* is the friendly name of the Lifecycle Rule and the *values* set the configuration of the rule. The map must include the following arguments:

  * **prefix** = The prefix (path) to which the Lifecycle Rule applies (i.e. if set to *example*, the rule will apply only to objects within the *example* directory.)
      * When rule applies to all objects, this argument is set to null.
  * **expiration** = The number of days, after which, an object should be permanently deleted from the S3 Bucket.
  * **noncurrent_version_expiration** = The number of days, after which, a non-current version of an object should be permanently deleted from the S3 Bucket.
  * **transitions** = A map of transitions for objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
      * If a transition is not required, set this argument to *{}*.
  * **noncurrent_version_transitions** = A map of transitions for non-current versions of objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
      * If a non-current version transition is not required, set this argument to *{}*.


### Logging Bucket
This module supports configuring the S3 Bucket to capture Elastic Load Balancer and S3 Access Logs. By default, each AWS Account contains a default S3 Bucket for Elastic Load Balancer and S3 Access Logs, however, in some specific cases, an additional bucket may need provisioning for this purpose.

This feature is enabled when the *is_logging_bucket* variable is set to *true*.

S3 Access Logs are **critical** to properly maintaining S3 storage. However, in rare cases, a bucket configuration may need to *temporarily* disable access logging. Access Logging is disabled when the *enable_access_logs* variable is set to *false*.  
&nbsp;


### Custom CORS Rules
This module supports configuring a custom CORS Rule for the S3 Bucket, allowing the S3 Bucket to server Cross-Origin requests when configured as an AWS CloudFront Distribution Origin. This feature is enabled when a valid value is provided to *any* of the following variables:

    * **allowed_headers** = A List of headers that are allowed when making requests to the S3 Bucket.
    * **allowed_methods** = A List of methods (GET, PUT, POST, etc) that are allowed when making requests to the S3 Bucket.
    * **allowed_origins** = A List of origins that are allowed to make cross-domain requests to the S3 Bucket.
    * **expose_headers** = A List of headers to allow in responses to requests to the S3 Bucket.


### Disable Access Logs
This module is, by default, configured to deliver S3 Access Logs to a centralized S3 Logging Bucket. This feature is disabled when the *enable_access_logs* variable is set to *false*. 

S3 Access Logs are **critical** to properly maintaining S3 storage. This feature should only be used **temporarily** for troubleshooting or in cases where teh S3 Logging Bucket has not yet been configured for an AWS Account.  
&nbsp;

### CloudTrail Logging
This module supports enabling CloudTrail logs for the provisioned S3 Bucket(s) Data Events. This feature is enabled when the *enable_cloudtrail* variable is set to *true*. 

By default, all S3 Management Events are captured and logged by *Organization* Trails. However, in some cases, it may be necessary for S3 *Data* Events to be captured by CloudTrail.  
&nbsp;

### Delete Unemptied Buckets
This module supports configuring an S3 Bucket that may be deleted **without deleting the objects stored within the bucket**. This feature is enabled when *delete_unemptied_bucket* is set to *true*.

**Important Notice**
By default, all objects stored by an S3 Bucket must be deleted *before* the S3 Bucket can be deleted. This provides a failsafe to prevent accidental deletion of S3 Buckets that still contain data. It is therefore **Not Recommended** to set *delete_unemptied_bucket* to *true*. However, to simplify purposeful bucket deletion via Terraform, this option is provided and may be **temporarily** enabled.  
&nbsp;


## Dependencies
The following resources are always required for the module:

    * KMS Key (used to encrypt the bucket)

If creating an S3 Bucket with Replication enabled, the following resources are required prior to deployment of this module:

    * KMS Key (used to encrypt the replication bucket)



## Example
### Example with only *required* variables
        module "s3" {
          source              = "./modules/s3"
          environment         = "prod"
          bucket_name         = "example"
          kms_key_arn         = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          data_classification = "internal confidential"

          providers = {
            aws.account       = aws.east
            aws.replication   = aws.west
          }
        }

### Example with *all* variables
        module "s3" {
          source                  = "./modules/s3"
          project                 = "example-project"
          environment             = "prod"
          bucket_name             = "example"
          kms_key_arn             = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          data_classification     = "internal confidential"
          replicate_bucket        = true 
          kms_key_arn_replication = "arn:aws:kms:us-west-2:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          default_bucket_policy   = false
          allowed_headers         = ["Example"]
          allowed_methods         = ["GET", "HEAD"]
          allowed_origins         = ["https://example.com", "https://one.example.com"]
          expose_headers          = ["Example"]
          max_age_seconds         = 5000
          enable_cloudtrail       = true
          delete_unemptied_bucket = true
          enable_access_logs      = false
          lifecycle_rules         = {
            example-lifecycle-rule = {
              prefix                        = "example"
              expiration                    = 365
              noncurrent_version_expiration = 180
              transitions = {
                90 = "GLACIER"
              }
              noncurrent_version_transitions = {
                90 = "GLACIER"
              }
            }   
          }

          providers = {
            aws.account       = aws.east
            aws.replication   = aws.west
          }
        }



## Variables

### Required Variables
* **environment** *string* = Environment that the S3 Bucket will support. 
    * Valid options are 'dev', 'staging', 'prod', or 'core'.
* **bucket_name** *string* = Friendly name for the S3 Bucket.
    * The module will automatically append the *bucket_name* to the AWS Region and Account Name to generate the full name of the S3 Bucket. (i.e. *example* may become *us-east-1-account-example*)
* **kms_key_arn** *string* = ARN of the KMS Key used to encrypt the S3 Bucket.
* **data_classification** *string* = data classification of data stored within the S3 Bucket. 
    * Valid options are 'public', 'strategic', 'internal confidential' or 'client confidential'.
    * Defined value will be set as a tag on the S3 Bucket (i.e. *data classification:confidential*).


### Optional Variables
* **project** *string* = Friendly name of the project the S3 Bucket supports. 
    * Enables override of naming conventions when the S3 Bucket supports a project within and AWS Account that is not named after that project. F
* **tags** *map(string)* = A map of additional tags to add to the resources provisioned by the module.


#### Replication
* **replicate_bucket** *boolean* = Sets whether to provision a secondary S3 Bucket and configure a Replication Rule to sync objects between the two S3 Buckets.
    * Defaults to *false*.
    * When set to *true*, the *kms_key_arn_replication* variable is required.
* **kms_key_arn_replication** *string* = RN of the KMS Key used to encrypt the secondary S3 Bucket.


#### Custom Bucket Policies
* **default_bucket_policy** *string* = Sets whether to attach a default bucket policy to the S3 Bucket.
    * Defaults to *true*.


#### Lifecycle Rules
* **lifecycle_rules** *map* = Map of the Lifecycle Rule configurations to be allied to the S3 Bucket.
    * Allows for the configuration fo multiple Lifecycle Rules.
    * The following arguments must be set within the map:
        * **prefix** = The prefix (path) to which the Lifecycle Rule applies (i.e. if set to *example*, the rule will apply only to objects within the *example* directory.)
            * When rule applies to all objects, this argument is set to null.
        * **expiration** = The number of days, after which, an object should be permanently deleted from the S3 Bucket.
        * **noncurrent_version_expiration** = The number of days, after which, a non-current version of an object should be permanently deleted from the S3 Bucket.
        * **transitions** = A map of transitions for objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
            * If a transition is not required, set this argument to *{}*.
        * **noncurrent_version_transitions** = A map of transitions for non-current versions of objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
            * If a non-current version transition is not required, set this argument to *{}*.

#### Logging Bucket
* **is_logging_bucket** *boolean* = Sets whether to configure the S3 Bucket to be able to capture Access Logs from Elastic Load Balancers and/or S3 Buckets.
* **enable_access_logs** *boolean* = Sets whether to deliver S3 Access Logs to the centralized S3 Logging Bucket for the AWS Account.
    * Defaults to *true*.
    * S3 Access Logs are **critical** to properly maintaining S3 storage. This feature should only be used **temporarily** for troubleshooting or in cases where the S3 Logging Bucket has not yet been configured for an AWS Account.
#### Custom CORS Rules
* **allowed_headers** *list* = List of headers that are allowed when making requests to the S3 Bucket.
* **allowed_methods** *list* = List of methods (GET, PUT, POST, etc) that are allowed when making requests to the S3 Bucket.
* **allowed_origins** *list* = List of origins that are allowed to make cross-domain requests to the S3 Bucket.
* **expose_headers** *list* = List of headers to allow in responses to requests to the S3 Bucket.
* **max_age_seconds** *number* = The amount of time (seconds) that browsers can cache the response for a preflight request via CORS policy
#### Cloudtrail Logging
* **enable_cloudtrail** *boolean* = Sets whether to create an AWS CloudTrail Trail for S3 Events.
    * Defaults to *false*.
    * When enabled, a CloudTrail Trail is provisioned to capture Object-Level Data Events related to the provisioned S3 Bucket.

#### Delete Unemptied Bucket
* **delete_unemptied_bucket** *boolean* = Sets whether to allow the deletion of the S3 Bucket even when the bucket contains data.
    * Defaults to *false*.

## Outputs

### Bucket Outputs
Bucket Outputs are presented as Maps to allow for simplified output referencing when replication is enables. In all cases, the map *key* is the AWS Region in which the bucket has been provisioned.

For example, if the module provisions two S3 Buckets, one in us-east-1 and another in us-west-2, the arn of the S3 Bucket in the East region may be referenced via *module.example.bucket_arn["us-east-1"]*, while the S3 Bucket in the West region may be referenced via *module.example.bucket_arn["us-west-2"]*.

* **bucket_name** = Friendly name of the S3 Bucket.
* **bucket_arn** = ARN of the S3 Bucket.
* **bucket_id** = Name of the S3 bucket.
* **bucket_domain_name** = Domain name of the S3 bucket
* **bucket_hosted_zone_id** = Route 53 Hosted Zone ID of the S3 bucket.
* **bucket_regional_domain_name** = Domain name with Region Name of the S3 bucket.

### Replication Role Outputs
* **bucket_replication_role_name** = Name of the IAM Role used for replicating objects between buckets.
* **bucket_replication_role_arn** = ARN of the IAM Role used for replicating objects between buckets.
* **bucket_replication_role_id**  = ID of the IAM Role used for replicating objects between buckets.
* **bucket_replication_role_unique_id** = Unique ID of the IAM Role used for replicating objects between buckets.
