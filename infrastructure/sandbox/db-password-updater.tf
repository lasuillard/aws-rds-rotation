locals {
  functions_dir = "${path.module}/functions"
}

module "rds_password_updater" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "${var.project_name}-rds-password-updater"
  description   = "Function to update the RDS instance password."

  runtime = "python3.14"
  handler = "main.lambda_handler"

  source_path    = "${local.functions_dir}/rds-password-updater/main.py"
  create_package = true

  attach_policy_statements = true
  policy_statements = {
    secrets = {
      effect  = "Allow"
      actions = ["secretsmanager:GetSecretValue"]
      resources = [
        aws_secretsmanager_secret.db_password.arn
      ]
    }
    rds = {
      effect  = "Allow"
      actions = ["rds:ModifyDBInstance"]
      resources = [
        "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:db:${local.db_id_prefix}*",
      ]
    }
  }

  cloudwatch_logs_retention_in_days = 3
}
