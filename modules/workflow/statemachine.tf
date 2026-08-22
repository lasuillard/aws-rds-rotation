locals {
  workflow_template_path = "${path.module}/statemachine/statemachine.tftpl.asl.json"

  workflow_template_raw_content = file(local.workflow_template_path)

  # Extract all workflow input names ($states.input.*)
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

  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [aws_lambda_function.lambda.arn]
  }

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
      "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:db:${var.db_id_prefix}*",
      "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:snapshot:*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [var.db_route53_zone_arn]
  }

  statement {
    sid       = "UpdateRoute53RecordForDatabase"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [var.db_route53_zone_arn]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = [var.db_route53_record_name]
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
  definition = templatefile(
    local.workflow_template_path,
    {
      db_id_prefix           = var.db_id_prefix
      lambda_function_name   = aws_lambda_function.lambda.function_name
      route53_hosted_zone_id = var.db_route53_zone_arn
      route53_domain_name    = var.db_route53_record_name
    }
  )
  publish = true

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.workflow.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

resource "aws_sfn_alias" "workflow" {
  name = "${var.project_name}-workflow"

  routing_configuration {
    state_machine_version_arn = aws_sfn_state_machine.workflow.state_machine_version_arn
    weight                    = 100
  }
}

resource "aws_cloudwatch_log_group" "workflow" {
  name_prefix       = "/aws/vendedlogs/states/${var.project_name}-workflow-"
  retention_in_days = 1
}
