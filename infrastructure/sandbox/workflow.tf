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

module "rds_rotation" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 5.0"

  name = "${var.project_name}-workflow"
  definition = jsonencode(yamldecode(templatefile(
    local.workflow_template_path,
    {
      # Give unique namespace for template variables to distinguish them in the template
      tftpl = {
        db_id_prefix                   = local.db_id_prefix
        db_subnet_group_name           = aws_db_subnet_group.db.name
        db_vpc_security_group_ids      = [module.db_sg.id]
        db_isolated_security_group_ids = [module.db_isolated_sg.id]
        db_tags                        = local.db_tags
        db_password_secret_id          = local.db_password_ref

        route53_hosted_zone_id = aws_route53_zone.phz.id
        route53_domain_name    = aws_route53_record.db.name

        # Components
        wait_for_ready = {
          state_machine_arn = module.wait_for_rds_ready.state_machine_arn
        }
        rds_password_updater = {
          lambda_function_name = module.rds_password_updater.lambda_function_name
        }
        data_sanitizer = {
          codebuild_project_name = aws_codebuild_project.data_sanitizer.name
        }
      }
    }
  )))

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }
  cloudwatch_log_group_retention_in_days = 3

  service_integrations = {
    lambda = {
      lambda = [module.rds_password_updater.lambda_function_arn]
    }

    stepfunction = {
      stepfunction = [module.wait_for_rds_ready.state_machine_arn]
    }

    # Express (synchronous) step function integration. Although our workflows use Standard type only,
    # this integration provides necessary IAM permissions for .sync integration of the step function.
    stepfunction_Sync = {
      # Omitted below because it is for Express Workflows (states:StartSyncExecution)
      # stepfunction = [...]

      stepfunction_Wildcard = [
        "arn:aws:states:${local.aws_region}:${local.aws_account_id}:execution:${module.wait_for_rds_ready.state_machine_name}:*"
      ]
      events = true
    }

    codebuild_StartBuild_Sync = {
      codebuild = [aws_codebuild_project.data_sanitizer.arn]
      events    = ["arn:aws:events:${local.aws_region}:${local.aws_account_id}:rule/StepFunctionsGetEventForCodeBuildStartBuildRule"]
    }
  }

  attach_policy_statements = true
  policy_statements = {
    rds_describe = {
      effect = "Allow"
      actions = [
        "rds:DescribeDBInstances",
        "rds:RestoreDBInstanceFromDBSnapshot",
      ]
      resources = ["*"]
    }
    rds_modify = {
      effect = "Allow"
      actions = [
        "rds:ModifyDBInstance",
        "rds:DeleteDBInstance",
        "rds:AddTagsToResource"
      ]
      resources = [
        "arn:aws:rds:${local.aws_region}:${local.aws_account_id}:db:${local.db_id_prefix}*",
      ]
    }
    route53 = {
      effect    = "Allow"
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = [aws_route53_zone.phz.arn]
      condition = [{
        test     = "ForAllValues:StringEquals"
        variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
        values   = [var.route53_db_record_name]
      }]
    }
  }
}

# Sub-workflow as "wait for RDS ready" state machine
module "wait_for_rds_ready" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 5.0"

  name       = "${var.project_name}-wait-for-rds-ready"
  definition = jsonencode(yamldecode(file("${local.workflow_template_dir}/wait-for-rds-ready.asl.yaml")))

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }
  cloudwatch_log_group_retention_in_days = 3

  attach_policy_statements = true
  policy_statements = {
    rds_describe = {
      effect    = "Allow"
      actions   = ["rds:DescribeDBInstances"]
      resources = ["*"]
    }
  }
}
