locals {
  # SQL source files
  sql_s3_prefix = "source/"
  sql_s3_key    = "${local.sql_s3_prefix}sql.zip"
}

module "codebuild_artifacts" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket_prefix = "${var.project_name}-db-sanitizer-"
  force_destroy = true
}

# SQL files to be executed by the CodeBuild project to sanitize the database
# NOTE: It should run in order of the SQL files within the zip archive, by their filenames:
#       e.g. 001-first.sql -> 002-second.sql -> 100-last.sql
data "archive_file" "sql_zip" {
  type        = "zip"
  source_dir  = "${path.module}/sql"
  output_path = "${path.module}/sql.zip"
}

resource "aws_s3_object" "sql_zip" {
  bucket = module.codebuild_artifacts.s3_bucket_id
  key    = local.sql_s3_key
  source = data.archive_file.sql_zip.output_path
  etag   = filemd5(data.archive_file.sql_zip.output_path)
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_name}-db-sanitizer-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
}

data "aws_iam_policy_document" "db_sanitizer_role_policy" {
  # Allow EC2 network interface management for CodeBuild within a VPC
  # https://docs.aws.amazon.com/codebuild/latest/userguide/auth-and-access-control-iam-identity-based-access-control.html#customer-managed-policies-example-create-vpc-network-interface
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterfacePermission",
    ]
    resources = ["arn:aws:ec2:${local.aws_region}:${local.aws_account_id}:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "ec2:Subnet"
      values   = [aws_subnet.private_1.arn, aws_subnet.private_2.arn]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeDhcpOptions",
    ]
    resources = ["*"]
  }

  # Allow S3 access for the SQL files used by the CodeBuild project
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketLocation"
    ]
    resources = ["${module.codebuild_artifacts.s3_bucket_arn}/*"]
  }

  # Allow logging to CloudWatch
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.db_sanitizer_logs.arn,
      "${aws_cloudwatch_log_group.db_sanitizer_logs.arn}:*"
    ]
  }

  # Allow reading the database password from Secrets Manager
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.db_password_ref]
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "${var.project_name}-codebuild-policy"
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.db_sanitizer_role_policy.json
}

resource "aws_cloudwatch_log_group" "db_sanitizer_logs" {
  name              = "/aws/codebuild/${var.project_name}-db-sanitizer"
  retention_in_days = 3
}

resource "aws_codebuild_project" "db_sanitizer" {
  name         = "${var.project_name}-db-sanitizer"
  description  = "Database sanitization pipeline for ${var.project_name}"
  service_role = aws_iam_role.codebuild_role.arn

  vpc_config {
    vpc_id             = aws_vpc.main.id
    subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.db_sanitizer.id]
  }

  build_timeout = 60 # In minutes

  source {
    type     = "S3"
    location = "${module.codebuild_artifacts.s3_bucket_id}/${local.sql_s3_key}"
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        install = {
          commands = [
            "echo 'Installing PostgreSQL client...'",
            "apt-get update && apt-get install --yes postgresql-client"
          ]
        }
        pre_build = {
          commands = [
            "echo 'Checking database connection...'",
            "PGPASSWORD=\"$DB_PASSWORD\" psql --host=\"$DB_HOST\" --username=\"$DB_USER\" --dbname=\"$DB_NAME\" --command='SELECT 1;'"
          ]
        }
        build = {
          commands = [
            "echo 'Running SQL files...'",
            <<-COMMAND
            sql_files=($(ls *.sql))
            for sql_file in "$${sql_files[@]}"; do
              echo "Running $sql_file..."
              PGPASSWORD="$DB_PASSWORD" psql --host="$DB_HOST" --username="$DB_USER" --dbname="$DB_NAME" --file="$sql_file"
            done
            COMMAND
          ]
        }
        post_build = {
          commands = [
            "echo 'Data sanitization completed.'"
          ]
        }
      }
    })
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    type                        = "LINUX_CONTAINER"
    image                       = "aws/codebuild/standard:8.0"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "DB_PASSWORD"
      value = local.db_password_ref
      type  = "SECRETS_MANAGER"
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.db_sanitizer_logs.name
    }
  }
}

resource "aws_security_group" "db_sanitizer" {
  vpc_id = aws_vpc.main.id

  name_prefix = "${var.project_name}-db-sanitizer-sg-"
  description = "Security group for the db sanitizer"
}

resource "aws_vpc_security_group_egress_rule" "db_sanitizer_to_all" {
  security_group_id = aws_security_group.db_sanitizer.id

  description = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_vpc_security_group_egress_rule" "db_sanitizer_to_rds" {
  security_group_id = aws_security_group.db_sanitizer.id

  description = "Allow access to the RDS instance from the CodeBuild project"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}
