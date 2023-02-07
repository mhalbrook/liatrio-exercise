# Backends Module

## Table of Contents

    Description
        * Resources
    Usage
        * Deploying the Infrastructure
            

## Description
This Terraform module deploys the AWS Resources that support Terraform's Remote Backend.  
&nbsp;

### Resources
The following resources are provisioned by the module:

    * KMS Key to encrypt Remote Backend resources
    * Multi-regional S3 Bucket to store Terraform State Files (Objects are replicated between buckets)
    * DynamoDB Table to perform State Locks when Terraform is reading and/or provisioning resources


## Usage

### Deploying the Infrastructure
To deploy the module, run the following commands:

        terraform workspace select core
        terraform init --upgrade
        terraform apply