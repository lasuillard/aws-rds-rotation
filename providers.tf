provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project      = "aws-rds-rotation"
      Source       = "https://github.com/lasuillard/aws-rds-rotation"
      "Managed-By" = "Terraform"
    }
  }
}
