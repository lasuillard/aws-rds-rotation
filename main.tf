terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project      = "aws-rds-rotation"
      Source       = "https://github.com/lasuillard/aws-rds-rotation"
      "Managed-By" = "Terraform"
    }
  }
}

locals {
  project_name = "aws-rds-rotation"

  aws_region     = data.aws_region.current.region
  aws_account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}
