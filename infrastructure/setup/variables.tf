variable "project_name" {
  type        = string
  description = "Project name used for naming resources"
  default     = "aws-rds-rotation"
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
  default     = "ap-northeast-2"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "vpc_public_subnet_cidr_block" {
  type        = string
  description = "VPC public subnet CIDR block"
  default     = "10.0.0.0/24"
}

variable "vpc_private_subnet_1_cidr_block" {
  type        = string
  description = "VPC private subnet 1 CIDR block to host EC2, RDS and Lambda."
  default     = "10.0.1.0/24"
}

variable "vpc_private_subnet_2_cidr_block" {
  type        = string
  description = "VPC private subnet 2 CIDR block. It is not used, but is required for RDS subnet group."
  default     = "10.0.2.0/24"
}

variable "db_name" {
  type        = string
  description = "Name of the database"
  default     = "demo"
}

variable "db_username" {
  type        = string
  description = "Master username for the database"
  default     = "dbadmin"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Master user password for the database"
  default     = null
}

variable "create_db_snapshot" {
  type        = bool
  description = "Whether to create the final DB snapshot on deletion. When enabled, a snapshot that is outside of state management will be created."
  default     = true
}

variable "db_snapshot_identifier" {
  type        = string
  description = "Identifier for the DB snapshot"
  default     = null
}
