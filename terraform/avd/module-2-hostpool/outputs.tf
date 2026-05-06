output "hostpool_id" {
  description = "ID des AVD Host Pools → in module-3-sessionhosts als hostpool_id eintragen"
  value       = azurerm_virtual_desktop_host_pool.main.id
}

output "hostpool_name" {
  description = "Name des AVD Host Pools"
  value       = azurerm_virtual_desktop_host_pool.main.name
}

output "registration_token" {
  description = "Registrierungstoken für Session Host Join (in module-3-sessionhosts verwenden)"
  value       = azurerm_virtual_desktop_host_pool_registration_info.main.token
  sensitive   = true
}

output "workspace_id" {
  description = "ID des AVD Workspace"
  value       = azurerm_virtual_desktop_workspace.main.id
}

output "dag_id" {
  description = "ID der Desktop Application Group"
  value       = azurerm_virtual_desktop_application_group.desktop.id
}
