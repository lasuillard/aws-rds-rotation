provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project      = var.project_name
      Source       = "https://github.com/lasuillard/aws-rds-rotation"
      "Managed-By" = "Terraform"
    }
  }
}
