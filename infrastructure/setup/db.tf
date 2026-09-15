
locals {
  db_host = split(":", module.db.db_instance_endpoint)[0]
  db_port = split(":", module.db.db_instance_endpoint)[1]

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password == null ? random_password.db[0].result : var.db_password

  db_snapshot_identifier = coalesce(var.db_snapshot_identifier, "${var.project_name}-base-snapshot")
}

resource "random_password" "db" {
  count = var.db_password == null ? 1 : 0

  length           = 28
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.0"

  identifier = "${var.project_name}-initial"

  engine         = "postgres"
  engine_version = "18"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp2"
  multi_az          = false

  db_name                     = local.db_name
  username                    = local.db_username
  password_wo                 = local.db_password
  password_wo_version         = 1
  manage_master_user_password = false

  # Keep existing behavior: don't create parameter/option groups
  create_db_parameter_group = false
  create_db_option_group    = false

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot              = !var.create_db_snapshot
  final_snapshot_identifier_prefix = local.db_snapshot_identifier
}

check "db_snapshot_does_not_exist" {
  data "aws_rds_snapshots" "existing" {
    filter {
      name   = "db-snapshot-id"
      values = [local.db_snapshot_identifier]
    }
  }

  assert {
    condition     = data.aws_rds_snapshots.existing.snapshots == null
    error_message = "DB snapshot with identifier ${local.db_snapshot_identifier} already exists."
  }
}

resource "aws_security_group" "db" {
  vpc_id = module.vpc.vpc_id

  name_prefix = "${var.project_name}-db-sg-"
  description = "Database security group"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_bastion" {
  security_group_id = aws_security_group.db.id

  description = "Allow connection from bastion host"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "null_resource" "db_initializer" {
  depends_on = [module.db, null_resource.wait_for_bastion_ready]

  # Load Pagila dataset (https://github.com/devrimgunduz/pagila)
  provisioner "local-exec" {
    environment = {
      PGDATABASE = local.db_name
      PGUSER     = local.db_username
      PGPASSWORD = local.db_password

      # Prevent connection blocking due to transient network issues
      PGCONNECT_TIMEOUT = 30
    }
    command = <<-CMD
      '${path.module}/scripts/init-db.sh' 5432 '${module.bastion.id}' '${local.db_host}' '${local.db_port}'
    CMD
  }
}
