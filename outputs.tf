output "base_snapshot_id" {
  description = "Base snapshot identifier to use for rotation."
  value       = module.core.base_snapshot_id
}

output "psql_command" {
  sensitive   = true
  description = "The command to connect to the database. You should establish the tunnel first and run this command."
  value       = module.core.psql_command
}

output "workflow_command" {
  description = "Command to trigger the step function workflow."
  value       = module.workflow.workflow_command
}

output "workflow_input" {
  description = "Example JSON for the available step function workflow inputs."
  value       = module.workflow.workflow_input
}
