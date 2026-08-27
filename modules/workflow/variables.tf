variable "project_name" {
  type        = string
  description = "Project name used for naming resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the workflow resources will be deployed"
}

variable "lambda_subnets" {
  type        = list(string)
  description = "List of subnet IDs for the Lambda functions"
}

variable "db_id_prefix" {
  type        = string
  description = "Prefix for the RDS database identifier"
}

variable "db_security_group_id" {
  type        = string
  description = "Security group ID of the RDS instance that the Lambda functions will connect to"
}

variable "db_route53_zone_arn" {
  type        = string
  description = "Hosted zone ARN for the Route53 record of the RDS instance"
}

variable "db_route53_zone_id" {
  type        = string
  description = "Hosted zone ID for the Route53 record of the RDS instance"
}

variable "db_route53_record_name" {
  type        = string
  description = "Route53 record name for the RDS instance"
}
