output "base_snapshot_id" {
  description = "Base snapshot identifier to use for rotation."
  value       = local.db_snapshot_identifier
}
