output "workflow_command" {
  description = "Command to trigger the step function workflow."
  value       = <<-CMD
    aws stepfunctions start-execution \
      --state-machine-arn='${aws_sfn_alias.workflow.arn}' \
      --input file://<path-to-input-json>
  CMD
}

output "workflow_input" {
  description = "Example JSON for the available step function workflow inputs."
  value = jsonencode({
    for key in local.workflow_input_names : key => ""
  })
}
