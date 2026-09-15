module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr_block

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = [var.vpc_public_subnet_cidr_block]
  private_subnets = [var.vpc_private_subnet_1_cidr_block, var.vpc_private_subnet_2_cidr_block]

  create_igw = true

  map_public_ip_on_launch = true
  enable_dns_hostnames    = true
  enable_dns_support      = true
}
