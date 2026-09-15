data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name = "${var.project_name}-bastion"

  ami                    = data.aws_ami.al2023.id
  instance_type          = "t4g.micro"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.bastion_sg.id]
}

resource "null_resource" "wait_for_bastion_ready" {
  depends_on = [module.bastion]

  provisioner "local-exec" {
    command = <<-CMD
      '${path.module}/scripts/wait-for-ready.sh' '${module.bastion.id}' \
    CMD
  }
}

module "bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "${var.project_name}-bastion-sg"
  description = "Security group for the bastion host"
  vpc_id      = module.vpc.vpc_id

  egress_rules = {
    all_https = {
      description = "Allow all outbound HTTPS traffic (for the Session Manager)"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
    }
    rds = {
      description                  = "Allow access to the RDS instance from the bastion host"
      ip_protocol                  = "tcp"
      from_port                    = 5432
      to_port                      = 5432
      referenced_security_group_id = module.db_sg.id
    }
  }
}
