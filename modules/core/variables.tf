variable "project_name" {
  type        = string
  description = "Project name used for naming resources"
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
