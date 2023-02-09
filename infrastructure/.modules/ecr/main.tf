################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  project        = var.project != null ? var.project : data.aws_iam_account_alias.account.account_alias                                                                                                                                                  # if a project is not provided, set the project to the IAM Alias of the AWS Account in which resources are provisioned
  full_repo_name = var.pull_through_cache_image_namespace != null ? format("pull-through-cache/%s/%s", trimsuffix(var.pull_through_cache_image_namespace, "/"), var.service_name) : format("%s-%s-%s", local.project, var.environment, var.service_name) # if the ECR is supporting Pull Through Cache, set the name to the namespace of Public Image being pulled, otherwise set the naming convention to align with standard schemas
  immutability   = var.enable_tag_immutability == false ? "MUTABLE" : "IMMUTABLE"                                                                                                                                                                        # Set the appropraite values for tag immutability
}

#############################################################
# Tagging Locals
#############################################################
locals {
  default_tags = {
    builtby     = "terraform"
    environment = var.environment
    service     = var.service_name
  }
}

#############################################################
# Lifecycle Policy Locals
#############################################################
locals {
  default_lifecycle = jsonencode(
    {
      rules = [
        {
          rulePriority = 1,
          description  = "Expire untagged images older than 7 days",
          selection = {
            tagStatus   = "untagged",
            countType   = "sinceImagePushed",
            countNumber = 7,
            countUnit   = "days"
          }
          action = {
            type = "expire"
          }
        }
      ]
    }
  )
}


################################################################################
# ECR Repository
################################################################################
resource "aws_ecr_repository" "ecr" {
  provider             = aws.account
  name                 = local.full_repo_name
  image_tag_mutability = local.immutability
  force_delete         = true
  tags                 = merge(var.tags, local.default_tags)

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}


################################################################################
# ECR Repository Policy
################################################################################
data "aws_iam_policy_document" "policy" {
  statement {
    sid     = "AllowPullImages"
    effect  = "Allow"
    actions = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:CompleteLayerUpload", "ecr:GetAuthorizationToken", "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.account.account_id]
    }

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.account.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [format("arn:aws:codebuild:%s:%s:project/*", data.aws_region.region.name, data.aws_caller_identity.account.account_id)]
    }
  }
}

resource "aws_ecr_repository_policy" "ecrpolicy" {
  provider   = aws.account
  repository = aws_ecr_repository.ecr.name
  policy     = data.aws_iam_policy_document.policy.json
}


################################################################################
# ECR Repository Lifecycle Policy
################################################################################
resource "aws_ecr_lifecycle_policy" "lifecycle" {
  provider   = aws.account
  repository = aws_ecr_repository.ecr.name
  policy     = var.lifecycle_policy != null ? var.lifecycle_policy : local.default_lifecycle
}
