# Terraform Library Module | ECR Repository 

**Current Version**: v1.0

This module creates an ECR Repository for storage of container images. 


## Known Issues
There are no known issues with this module.

## Providers
From a root module, set a provider for the account in which to provision the ECR Repository. When calling this Library module, set the provider equal to *aws.account*.

## Features 
### Repository Encryption
The module requires encryption of the ECR Repository via AWS KMS. This feature is enabled by providing a valid KMS Key ARN to the *kms_key_arn* variable.  
&nbsp;

### Tag Immutability
The module supports configuring Tag Immutability for images stored in the ECR Repository. This feature is enabled when *enable_tag_immutability* is set to *true*.

Tag Immutability will ensure that container image tags cannot be moved between containers in the ECR Repository. This feature can improve security by ensuring consistency of the container image being deployed.

By default, Tag Immutability is enabled.  
&nbsp;

### Lifecycle Policies
Lifecycle Policies allow for the configuration of rules that dictate how old images will be expired. For example, a policy may be configured to expire images after *n* days, unless the images have specific tags.  

If a Custom lifecycle Policy is not provided, a Default Lifecycle Policy is attached to the ECR Repository.
&nbsp;

#### Custom Lifecycle Policy
The module supports applying a custom Lifecycle Policy to the ECR Repository. This feature is enabled when a valid JSON-Formatted Lifecycle Policy is provided to the *lifecycle_policy* variable.  
&nbsp;

#### Default Lifecycle Policy
The module supports applying a default Lifecycle to the ECR Repository. This feature is enabled when the *lifecycle_policy* variable is not set.

The Default Lifecycle will delete untagged container images after seven days.  
&nbsp;

### Vulnerability Scanning
By default, the module enables vulnerability scanning of new images as they are pushed to the ECR Repository via AWS' Basic ECR Scanning. In most cases, ECR Registries are configured to automatically scan all ECR Repositories via AWS' Enhanced ECR Scanning. Since ECR Registry Scanning Configurations take precedence over ECR Repository Scanning Configurations, the scanning configuration enabled by this module is often irrelevant. However, enabling this feature for all repositories ensures images continue to be scanned if the EcR Registry Scanning Configuration is altered or mistakenly disable.

This feature cannot be disabled.  
&nbsp;

### Pull Through Cache
The module supports provisioning an ECR Repository to be used with a Pull Through Cache Rule. This feature is enabled when the *pull_through_cache_image_namespace* variable is set to a valid **namespace** of a Public Image within the AWS Public Registry.

Pull Through Cache Rules allow container images to be pulled from the AWS Public Registry and stored in a Private ECR Repository. This improves stability and security by eliminating the need to manage authorization credentials for Public Registries or pull images over the internet.

By default, Pull Through Cache Rules automatically generate ECR Repositories for images the first time the image is pulled using the rule. However, the ECR Repositories generated are not encrypted or configured for security scanning. Due to these limitations, it is best practice to provision an ECR Repository before pulling an image via a Pull Through Cache Rule.  

When this feature is enabled, the standard ECR Repository naming convention is ignored as Pull Through Cache Repository names must align with the Image's Namespace and  Name as they appear in the AWS Public Registry. For example, if the ECR Repository is storing the [DataDog Agent Image](https://gallery.ecr.aws/datadog/agent), then the *pull_through_cache_image_namespace* variable should be set to *datadog* as that is the name of the [Namespace in the AWS Public Registry](https://gallery.ecr.aws/datadog/). 

Additionally, the *service_name* variables should be set to the name of the Image as it appears in the AWS Public Registry. Using the same example, the *service_name* variable would be set to *agent* as that is the Name of the Image within the *datadog* namespace of the AWS Public Registry.    
&nbsp;

## Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules. 

The following resources are always required for the module:

    * KMS Key



## Example
### Example with only *required* variables
    module "ecr" {
      source       = "../.modules/ecr"
      environment  = "prod"
      project      = "example-project"
      service      = "example-service"
      kms_key_arn  = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

      providers = {
        aws.account = aws.example
      }
    }


### Example with *all* variables
    module "ecr" {
      source                             = "../.modules/ecr"
      environment                        = "prod"
      project                            = "example-project"
      service                            = "example-service"
      kms_key_arn                        = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      enable_tag_immutability            = true
      lifecycle_policy                   = data.lifecycle_policy.json
      pull_through_cache_image_namespace = "datadog"

      providers = {
        aws.account = aws.example
      }
    }



## Variables

### Required Variables
* **environment** *string* = Environment that the ECR Repository supports. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **project** *string* = Friendly name of the project the ECR Repository supports. 
    * Provided value is used to establish a name for the ECR Repository.
      * ECR Repository name is generated by appending the *environment* and *service_name* to the *project*.
      * Not required when the *pull_through_cache_image_namespace* is set.
* **service_name** *string* = Friendly Name of the service the ECR Repository supports.
* **kms_key_arn** *string* = The ARN of the KMS key used to encrypt the ECR Repository.


### Optional Variables
#### Tag Immutability
* **enable_tag_immutability** *boolean* = Sets whether to make Image Tags Immutable.
    * Defaults to *true* (tags are immutable).

#### Lifecycle Policies
* **lifecycle_policy** *object* = Custom Lifecycle Policy to attach to the ECR Repository.
    * Must be a valid JSON-Formatted Lifecycle Policy.

#### Pull Through Cache
* **pull_through_cache_image_namespace** *boolean* = The Namespace, as it appears within the AWS Public Registry, of the Image being pulled via a Pull Through Cache Rule.
    * Defaults to Null

## Outputs
#### ECR Repository Outputs
* **name** = Friendly name of the ECR Repository.
* **arn** = ARN of the ECR Repository.
* **registry_id** = ID of ECR Registry where the ECR Repository was created.
* **repository_url** = URL of the ECR Repository.
