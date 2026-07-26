locals {
  project_name = "aws-rds-rotation"

  aws_region     = data.aws_region.current.region
  aws_account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}
