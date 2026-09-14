
locals {
  db_host = split(":", aws_db_instance.db.endpoint)[0]
  db_port = split(":", aws_db_instance.db.endpoint)[1]

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

resource "aws_db_instance" "db" {
  identifier = "${var.project_name}-initial"

  engine                 = "postgres"
  engine_version         = "18"
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = false

  # Free-tier eligible
  instance_class    = "db.t4g.micro"
  storage_type      = "gp2"
  allocated_storage = 20

  db_name  = local.db_name
  username = local.db_username
  password = local.db_password

  # Create final snapshot (if configured)
  skip_final_snapshot       = !var.create_db_snapshot
  final_snapshot_identifier = local.db_snapshot_identifier
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

resource "aws_db_subnet_group" "db" {
  name_prefix = "${var.project_name}-db-subnet-group-"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_security_group" "db" {
  vpc_id = aws_vpc.main.id

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
  depends_on = [aws_db_instance.db, null_resource.wait_for_bastion_ready]

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
      '${path.module}/scripts/init-db.sh' 5432 '${aws_instance.bastion.id}' '${local.db_host}' '${local.db_port}'
    CMD
  }
}
