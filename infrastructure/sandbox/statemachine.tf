locals {
  workflow_template_dir         = "${path.module}/statemachine"
  workflow_template_path        = "${local.workflow_template_dir}/statemachine.tftpl.asl.yaml"
  workflow_template_raw_content = file(local.workflow_template_path)

  # Extract all workflow input names ($states.input.*) (convenience feature)
  workflow_input_names = toset(flatten(regexall(
    "\\$states\\.input\\.([a-zA-Z0-9_.-]*[a-zA-Z0-9_-]+)",
    local.workflow_template_raw_content
  )))
}

data "aws_iam_policy_document" "workflow_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "workflow" {
  name_prefix        = "${var.project_name}-workflow-role-"
  assume_role_policy = data.aws_iam_policy_document.workflow_assume_role_policy.json
}

# https://aws.amazon.com/ko/blogs/devops/best-practices-for-writing-step-functions-terraform-projects/
data "aws_iam_policy_document" "workflow_role_policy" {
  # Allow logging actions
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:CreateLogStream",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutLogEvents",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }

  # Allow RDS instance management actions for specific RDS instances and snapshots
  statement {
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
      "rds:RestoreDBInstanceFromDBSnapshot",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:AddTagsToResource"
    ]
    resources = [
      "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:db:${local.db_id_prefix}*",
      "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:snapshot:*"
    ]
  }

  # Allow invocation of Lambda functions as part of the workflow
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      module.rds_password_updater.lambda_function_arn,
    ]
  }

  # Allow sub state machine (component) execution
  statement {
    effect  = "Allow"
    actions = ["states:StartExecution"]
    resources = [
      aws_sfn_state_machine.wait_for_rds_ready.arn
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["states:DescribeExecution", "states:StopExecution"]
    resources = [
      "arn:aws:states:${local.aws_region}:${local.aws_account_id}:execution:${aws_sfn_state_machine.wait_for_rds_ready.name}:*"
    ]
  }

  # .sync integration
  statement {
    effect    = "Allow"
    actions   = ["events:PutRule", "events:PutTargets", "events:DescribeRule"]
    resources = ["arn:aws:events:${local.aws_region}:${local.aws_account_id}:rule/StepFunctions*"]
  }

  # Allow Route 53 record updates for traffic switching
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [aws_route53_zone.phz.arn]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = [var.route53_db_record_name]
    }
  }
}

resource "aws_iam_policy" "workflow" {
  name_prefix = "${var.project_name}-workflow-policy-"
  policy      = data.aws_iam_policy_document.workflow_role_policy.json
}

resource "aws_iam_role_policy_attachments_exclusive" "workflow" {
  role_name = aws_iam_role.workflow.name
  policy_arns = [
    aws_iam_policy.workflow.arn
  ]
}

resource "aws_sfn_state_machine" "workflow" {
  depends_on = [
    aws_iam_role_policy_attachments_exclusive.workflow # Ensure policy is attached to the role
  ]

  name_prefix = "${var.project_name}-workflow-"
  role_arn    = aws_iam_role.workflow.arn
  definition = jsonencode(yamldecode(templatefile(
    local.workflow_template_path,
    {
      # Give unique namespace for template variables to distinguish them in the template
      tftpl = {
        db_id_prefix           = local.db_id_prefix
        db_subnet_group_name   = aws_db_subnet_group.db.name
        publicly_accessible    = false
        vpc_security_group_ids = [aws_security_group.db.id]
        db_tags                = local.db_tags
        db_password_secret_id  = local.db_password_ref

        route53_hosted_zone_id = aws_route53_zone.phz.id
        route53_domain_name    = var.route53_db_record_name

        # Components
        wait_for_rds_ready_state_machine_arn = aws_sfn_state_machine.wait_for_rds_ready.arn
        rds_password_updater_function_name   = module.rds_password_updater.lambda_function_name
        data_sanitization_project_name       = aws_codebuild_project.db_sanitizer.name
      }
    }
  )))

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.workflow.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

# Sub-workflow as "wait for RDS ready" state machine
resource "aws_sfn_state_machine" "wait_for_rds_ready" {
  name_prefix = "${var.project_name}-wait-for-rds-ready-"
  role_arn    = aws_iam_role.workflow.arn
  definition  = jsonencode(yamldecode(file("${local.workflow_template_dir}/wait-for-rds-ready.asl.yaml")))
}

resource "aws_cloudwatch_log_group" "workflow" {
  name_prefix       = "/aws/vendedlogs/states/${var.project_name}-workflow-"
  retention_in_days = 1
}
