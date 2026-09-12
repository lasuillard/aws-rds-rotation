locals {
  functions_dir = "${path.module}/functions"
}

data "aws_iam_policy_document" "rds_password_updater_role_policy" {
  statement {
    sid     = "AllowReadSecret"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.db_password.arn
    ]
  }

  statement {
    sid     = "UpdateRDSInstance"
    effect  = "Allow"
    actions = ["rds:ModifyDBInstance"]
    resources = [
      "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:db:${local.db_id_prefix}*",
    ]
  }
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

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.rds_password_updater_role_policy.json

  cloudwatch_logs_retention_in_days = 7
}

data "aws_iam_policy_document" "masker_role_policy" {
  statement {
    sid     = "AllowReadSecret"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.db_password.arn
    ]
  }

  statement {
    sid     = "AllowRetrieveConnectionInfo"
    effect  = "Allow"
    actions = ["rds:DescribeDBInstances"]
    resources = [
      "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:db:${local.db_id_prefix}*",
    ]
  }
}

module "masker" {
  depends_on = [data.aws_iam_policy_document.masker_role_policy]

  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "${var.project_name}-masker"
  description   = "Function to run SQL queries on the database, as part of the step function workflow."

  runtime = "python3.14"
  handler = "main.lambda_handler"

  source_path = [
    {
      path       = "${local.functions_dir}/masker"
      uv_install = true
    }
  ]
  create_package = true

  vpc_subnet_ids         = [aws_subnet.private_1.id]
  vpc_security_group_ids = [aws_security_group.lambda.id]

  attach_policies = true
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.masker_role_policy.json

  cloudwatch_logs_retention_in_days = 7
}

resource "aws_security_group" "lambda" {
  vpc_id = aws_vpc.main.id

  name_prefix = "${var.project_name}-lambda-sg-"
  description = "Security group for the Lambda functions"
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_rds" {
  security_group_id = aws_security_group.lambda.id

  description = "Allow access to the RDS instance from the Lambda functions"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}
