output "horizon_primary_ip" {
  description = "IP des primären Connection Server → in module-3-config als horizon_primary_ip eintragen"
  value       = var.cs_primary_ip
}

output "horizon_replica_ips" {
  description = "IPs der Replica Connection Server"
  value       = local.replica_ips
}
