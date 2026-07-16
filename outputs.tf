output "psql_command" {
  sensitive   = true
  description = "The command to connect to the database."
  value       = <<CMD
PGPASSWORD='${aws_db_instance.main.password}' psql \
  --host='${local.db_host}' \
  --port='${local.db_port}' \
  --dbname='${aws_db_instance.main.db_name}' \
  --username='${aws_db_instance.main.username}'
CMD
}
