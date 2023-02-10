# liatrio-exercise

## Overview
The liatrio-exercise provisions resources to host a simple Python service on AWS EKS Fargate. Once deployed, the service can be reached via the provided URL and will return a static message and the current timestamp.

### resources
The following resources are provisioned:
- Terraform Remote Backend Resources
    - S3 Bucket
    - KMS Key
    - DynamoDB Table
- AWS VPC
    - 2 Availability Zones
    - Public, Private, and Data Subnets in each AZ
    - NAT Gateways in Public Subnets
    - NACL Rules and Routes for required network traffic
- AWS ECR Repository
    - KMS Key
    - ECR Repo
    - Docker Image (pushed to ECR Repo)
- AWS EKS Cluster
    - EKS Cluster
    - CoreDNS Add-On
    - aws-load-balancer-controller Add-On
    - aws-load-balancer-controller Fargate Profile
    - Kubernetes Namespace (liatrio)
    - IAM Roles for aws-load-balancer-controller, EKS Cluster, and Pod Execution
- Kubernetes Service (service-a)
    - Fargate Profile
    - Kubernetes Service
    - Kubernetes Deployment
    - Kubernetes Ingress
    - AWS Application Load Balancer


## Requirements
The following tools must be installed in order to deploy the application
    terraform >=v1.3.6
    python >=v3.10.0
    aws-cli >=v2.9
    kubectl >=v1.23
    helm >=v3.11.0
    docker engine >=20.10.22

Additionally, the AWS CLI must be configured with valid credentials for the AWS Account in which the service is being deployed. The credentials must be stored under the 'default' profile of the ~/.aws/credentials file.

## Deploying
To deploy the application, navigate to the root of the repository from Terminal, then run the following command:

    pip3 install -r requirements.txt && python3 build.py --action apply

## Cleanup
To decommission the application, navigate to the root of the repository from Terminal, then run the following command: 

    python3 build.py --action destroy
