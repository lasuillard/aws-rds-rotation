resource "aws_route53_zone" "phz" {
  name          = var.route53_zone_name
  comment       = "Private hosted zone for demo purposes"
  force_destroy = true

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "aws_route53_record" "db" {
  lifecycle {
    # Ignore fields that may be updated outside of Terraform, in SFN.
    ignore_changes = [ttl, records]
  }

  zone_id = aws_route53_zone.phz.zone_id
  name    = var.route53_db_record_name
  type    = "CNAME"
  ttl     = 60

  # Before the first rotation workflow completes successfully, the database DNS record initially points to 127.0.0.1 (placeholder).
  # Any dependent applications starting in the sandbox before the first rotation will fail to connect.
  # You must run the rotation workflow at least once to populate the actual database endpoint in the DNS record.
  records = ["127.0.0.1"]
}
