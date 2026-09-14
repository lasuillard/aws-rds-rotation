output "workflow_command" {
  description = "Command to trigger the step function workflow."
  value       = <<-CMD
    aws stepfunctions start-execution \
      --state-machine-arn='${aws_sfn_state_machine.workflow.arn}' \
      --input file://<path-to-input-json>
  CMD
}

output "workflow_input" {
  description = "Example JSON for the available step function workflow inputs."
  value = jsonencode({
    for key in local.workflow_input_names : key => ""
  })
}

output "psql_command" {
  description = "`psql` command to connect to the database."
  value       = <<-CMD
    PGDATABASE='${local.db_name}' \
    PGUSER='${local.db_username}' \
    PGPASSWORD="$(aws secretsmanager get-secret-value --secret-id '${local.db_password_ref}' --query SecretString --output text)" \
    ${abspath("${path.module}/../../scripts/psql.sh")} \
      5432 '${aws_instance.bastion.id}' '${local.db_host}' '${local.db_port}'
  CMD
}
