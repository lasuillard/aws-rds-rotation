output "base_snapshot_id" {
  description = "Base snapshot identifier to use for rotation."
  value       = local.db_snapshot_identifier
}

output "psql_command" {
  description = "`psql` command to connect to the database."
  value       = <<-CMD
    PGDATABASE='${local.db_name}' \
    PGUSER='${local.db_username}' \
    PGPASSWORD='${local.db_password}' \
    ${abspath("${path.module}/../../scripts/psql.sh")} \
      5432 '${aws_instance.bastion.id}' '${local.db_host}' '${local.db_port}'
  CMD
}
