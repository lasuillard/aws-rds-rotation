resource "aws_route53_zone" "phz" {
  name          = "example.com"
  comment       = "Private hosted zone for example.com for demo purposes"
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.phz.zone_id
  name    = "db.example.com"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.db.address]
}
