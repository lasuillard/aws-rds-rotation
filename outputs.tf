output "base_snapshot_id" {
  description = "Base snapshot identifier to use for rotation."
  value       = aws_db_instance.db.snapshot_identifier
}

output "psql_command" {
  sensitive   = true
  description = "The command to connect to the database. You should establish the tunnel first and run this command."
  value       = "PGUSER='${aws_db_instance.db.username}' PGPASSWORD='${aws_db_instance.db.password}' PGDATABASE='${aws_db_instance.db.db_name}' ./scripts/psql.sh 5432 '${aws_instance.bastion.id}' '${aws_route53_record.db.name}' '${local.db_port}'"
}

output "workflow_command" {
  description = "Command to trigger the step function workflow."
  value       = <<CMD
aws stepfunctions start-execution \
  --state-machine-arn='${aws_sfn_state_machine.workflow.arn}' \
  --input file://<path-to-input-json>
CMD
}
