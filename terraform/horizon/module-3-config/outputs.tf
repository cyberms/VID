output "horizon_connection_server_url" {
  description = "URL des Horizon Connection Server"
  value       = "https://${var.horizon_primary_ip}/admin"
}

output "pool_name" {
  description = "Name des angelegten Desktop Pools"
  value       = var.pool_name
}
