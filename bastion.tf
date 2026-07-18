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

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # Free-tier eligible
  instance_type = "t4g.micro"

  tags = {
    Name = "${local.project_name}-bastion"
  }
}

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.main.id

  name_prefix = "${local.project_name}-bastion-sg-"
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
