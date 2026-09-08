resource "aws_route53_zone" "phz" {
  name          = var.route53_zone_name
  comment       = "Private hosted zone for demo purposes"
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "db" {
  lifecycle {
    ignore_changes = [records]
  }

  zone_id = aws_route53_zone.phz.zone_id
  name    = var.route53_db_record_name
  type    = "CNAME"
  ttl     = 60
  records = ["127.0.0.1"] # Placeholder for the actual RDS instance address
}
