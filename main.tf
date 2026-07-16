terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

locals {
  db_host = split(":", aws_db_instance.main.endpoint)[0]
  db_port = split(":", aws_db_instance.main.endpoint)[1]
}

resource "aws_db_instance" "main" {
  engine         = "postgres"
  engine_version = "18"

  # Free-tier eligible
  instance_class    = "db.t4g.micro"
  storage_type      = "gp2"
  allocated_storage = 20

  # WARNING: For demo purposes only!
  db_name             = "demo"
  username            = "dbadmin"
  password            = "sup5r3s3cr3t"
  publicly_accessible = true
  skip_final_snapshot = true
}

resource "null_resource" "db_initializer" {
  depends_on = [aws_db_instance.main]

  # Load Pagila dataset (https://github.com/devrimgunduz/pagila)
  provisioner "local-exec" {
    environment = {
      PGHOST     = local.db_host
      PGPORT     = local.db_port
      PGDATABASE = aws_db_instance.main.db_name
      PGUSER     = aws_db_instance.main.username
      PGPASSWORD = aws_db_instance.main.password

      PGCONNECT_TIMEOUT = 10
    }
    command = <<CMD
curl --fail --silent --show-error --location https://raw.githubusercontent.com/devrimgunduz/pagila/refs/heads/master/pagila-schema.sql | psql | tee --append db-init.log
curl --fail --silent --show-error --location https://raw.githubusercontent.com/devrimgunduz/pagila/refs/heads/master/pagila-data.sql | psql | tee --append db-init.log
CMD
  }
}
