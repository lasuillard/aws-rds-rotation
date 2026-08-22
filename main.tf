locals {
  project_name = "aws-rds-rotation"

  aws_region     = data.aws_region.current.region
  aws_account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

module "core" {
  source = "./modules/core"

  project_name = local.project_name
}

module "workflow" {
  source = "./modules/workflow"

  project_name = local.project_name

  vpc_id         = module.core.vpc_id
  lambda_subnets = module.core.private_subnets

  db_id_prefix           = module.core.db_id_prefix
  db_security_group_id   = module.core.db_security_group_id
  db_route53_zone_arn    = module.core.db_route53_zone_arn
  db_route53_record_name = module.core.db_route53_record_name
}
