
locals {
  db_host = split(":", aws_db_instance.db.endpoint)[0]
  db_port = split(":", aws_db_instance.db.endpoint)[1]

  # To track the state of the database restored/deleted externally,
  # we need to follow the RDS instance identifier using the pattern matching
  db_id_prefix  = "${var.project_name}-db-"
  db_id_default = "${local.db_id_prefix}00000000t000000"

  db_instance_ids = [
    for id in data.aws_db_instances.find_db.instance_identifiers : id
    if startswith(id, local.db_id_prefix)
  ]

  # The identifier of the database should be prefix-YYYYMMDD-HHMMSS
  # and we want only the latest one
  db_instance_ids_sorted_reverse = reverse(sort(local.db_instance_ids))

  db_id_dynamic = length(local.db_instance_ids_sorted_reverse) > 0 ? local.db_instance_ids_sorted_reverse[0] : local.db_id_default
}

data "aws_db_instances" "find_db" {
  // NOTE: Using Terraform functions to filter the list of RDS instances
  //       to find the database restored/deleted externally because the `filters` block
  //       does not support pattern matching
  tags = {
    Project = "aws-rds-rotation"
  }
}

resource "aws_db_instance" "db" {
  // TODO: Identifier will change after rotation, so state should be persisted after rotation
  identifier = local.db_id_dynamic

  engine                              = "postgres"
  engine_version                      = "18"
  db_subnet_group_name                = aws_db_subnet_group.db.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  multi_az                            = false
  iam_database_authentication_enabled = true

  # Free-tier eligible
  instance_class    = "db.t4g.micro"
  storage_type      = "gp2"
  allocated_storage = 20

  # WARNING: For demo purposes only!
  db_name             = "demo"
  username            = "dbadmin"
  password            = "sup5r3s3cr3t"
  skip_final_snapshot = true
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
      PGUSER     = aws_db_instance.db.username
      PGPASSWORD = aws_db_instance.db.password
      PGDATABASE = aws_db_instance.db.db_name

      # Prevent connection stuck due to network issues
      PGCONNECT_TIMEOUT = 30
    }
    command = <<CMD
'${path.module}/scripts/init-db.sh' 5432 '${aws_instance.bastion.id}' '${local.db_host}' '${local.db_port}'
CMD
  }
}

# Initial snapshot for demo (represents production database snapshot)
resource "aws_db_snapshot" "base" {
  depends_on = [null_resource.db_initializer]
  lifecycle {
    ignore_changes = [
      db_instance_identifier # This snapshot is just for demo, so we don't need to track the state of the this snapshot
    ]
  }

  db_instance_identifier = aws_db_instance.db.identifier
  db_snapshot_identifier = "${var.project_name}-base-snapshot"
}
