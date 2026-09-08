locals {
  db_id_prefix = coalesce(var.db_id_prefix, "${var.project_name}-db-")
}

check "dangling_db_instances" {
  data "aws_db_instances" "find_db" {
    // NOTE: Using Terraform functions to filter the list of RDS instances
    //       to find the database restored/deleted externally because the `filters` block
    //       does not support pattern matching
    tags = {
      Project = "aws-rds-rotation"
    }

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
