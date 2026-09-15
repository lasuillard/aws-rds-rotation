locals {
  db_id_prefix = coalesce(var.db_id_prefix, "${var.project_name}-db-")

  # NOTE: Hard-coded reference to default values of setup stack (for simplicity, for now)
  db_host = aws_route53_record.db.name
  db_port = var.db_port

  db_name         = var.db_name
  db_username     = var.db_username
  db_password_ref = aws_secretsmanager_secret.db_password.id

  # Selector tags used for assigning (while resource creation)
  # and filtering (selecting old database) the RDS instances for this project
  db_tags = {
    Project      = "aws-rds-rotation"
    "Managed-By" = "sfn"
  }
}

check "dangling_db_instances" {
  data "aws_db_instances" "find_db" {
    // NOTE: Using Terraform functions to filter the list of RDS instances
    //       to find the database restored/deleted externally because the `filters` block
    //       does not support pattern matching
    tags = local.db_tags
  }

  assert {
    # 0: Workflow hasn't run
    # 1: Workflow completed at least once
    # 2: Workflow in progress, multiple RDS instances may exist temporarily
    # 3+: More than 3 RDS instances exist, likely indicating a dangling instance which needs investigation
    condition     = length(data.aws_db_instances.find_db.instance_identifiers) <= 1
    error_message = "There are more than ${length(data.aws_db_instances.find_db.instance_identifiers)} RDS instances running. It may indicate a dangling instance if no running workflow exists."
  }
}

# Prohibited: slash (/), quote ('), double quote ("), at symbol (@), backtick (`)
resource "random_password" "db_password" {
  length           = 28
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/rds/db-password"

  # Forces immediate deletion if destroyed
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string = random_password.db_password.result
}

resource "aws_db_subnet_group" "db" {
  name_prefix = "${var.project_name}-db-subnet-group-"
  subnet_ids  = module.vpc.private_subnets
}

module "db_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "${var.project_name}-db-sg"
  description = "Database security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_bastion = {
      description                  = "Allow connection from bastion host"
      ip_protocol                  = "tcp"
      from_port                    = 5432
      to_port                      = 5432
      referenced_security_group_id = module.bastion_sg.id
    }
  }
}

module "db_isolated_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "${var.project_name}-db-isolated-sg"
  description = "Isolated Database security group for rotation"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_sanitizer = {
      description                  = "Allow inbound traffic from the db sanitizer security group only"
      ip_protocol                  = "tcp"
      from_port                    = 5432
      to_port                      = 5432
      referenced_security_group_id = module.data_sanitizer_sg.id
    }
  }
}
