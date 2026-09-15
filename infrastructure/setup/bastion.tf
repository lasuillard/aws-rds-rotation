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
  vpc_security_group_ids = [aws_security_group.bastion.id]
}

resource "aws_security_group" "bastion" {
  vpc_id = module.vpc.vpc_id

  name_prefix = "${var.project_name}-bastion-sg-"
  description = "Security group for the bastion host"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_all_https" {
  security_group_id = aws_security_group.bastion.id

  description = "Allow all outbound HTTPS traffic (for the Session Manager)"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_rds" {
  security_group_id = aws_security_group.bastion.id

  description = "Allow access to the RDS instance from the bastion host"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}

resource "null_resource" "wait_for_bastion_ready" {
  depends_on = [module.bastion]

  provisioner "local-exec" {
    command = <<-CMD
      '${path.module}/scripts/wait-for-ready.sh' '${module.bastion.id}' \
    CMD
  }
}
