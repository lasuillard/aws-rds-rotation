output "vpc_id" {
  description = "VPC ID where the core infrastructure resources are deployed."
  value       = aws_vpc.main.id
}

output "private_subnets" {
  description = "List of private subnet IDs where the core infrastructure resources are deployed."
  value       = [aws_subnet.private_1.id]
}

output "db_id_prefix" {
  description = "Prefix for the RDS database identifier."
  value       = local.db_id_prefix
}

output "base_snapshot_id" {
  description = "Base snapshot identifier to use for rotation."
  value       = aws_db_snapshot.base.db_snapshot_identifier
}

output "db_security_group_id" {
  description = "Security group ID of the RDS instance."
  value       = aws_security_group.db.id
}

output "db_route53_zone_arn" {
  description = "Hosted zone ARN for the Route53 record of the RDS instance."
  value       = aws_route53_zone.phz.arn
}

output "db_route53_record_name" {
  description = "Route53 record name for the RDS instance."
  value       = aws_route53_record.db.name
}

output "psql_command" {
  sensitive   = true
  description = "The command to connect to the database. You should establish the tunnel first and run this command."
  value       = "PGUSER='${aws_db_instance.db.username}' PGPASSWORD='' PGDATABASE='${aws_db_instance.db.db_name}' ./scripts/psql.sh 5432 '${aws_instance.bastion.id}' '${aws_route53_record.db.name}' '${local.db_port}'"
}
