data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name_prefix        = "${local.project_name}-lambda-role-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_role_policy" {
  statement {
    sid       = "UpdateRDSInstanceAndConnectIAMAuth"
    effect    = "Allow"
    actions   = ["rds:ModifyDBInstance", "rds-db:connect"]
    resources = [aws_db_instance.db.arn]
  }
}

resource "aws_iam_policy" "lambda" {
  name_prefix = "${local.project_name}-lambda-policy-"
  policy      = data.aws_iam_policy_document.lambda_role_policy.json
}

resource "aws_iam_role_policy_attachments_exclusive" "lambda" {
  role_name = aws_iam_role.lambda.name
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    aws_iam_policy.lambda.arn
  ]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/run-sql/src"
  output_path = "${path.module}/functions/run-sql/function.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name    = "${local.project_name}-run-sql"
  description      = "Function to run SQL queries on the database, as part of the step function workflow."
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  filename         = "${path.module}/functions/run-sql/function.zip"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "main.lambda_handler"

  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
}

resource "aws_security_group" "lambda" {
  vpc_id = aws_vpc.main.id

  name_prefix = "${local.project_name}-lambda-sg-"
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

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 1
}
