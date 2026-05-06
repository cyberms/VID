output "sessionhost_names" {
  description = "Namen der AVD Session Host VMs"
  value       = azurerm_windows_virtual_machine.sessionhost[*].name
}

output "sessionhost_private_ips" {
  description = "Private IP-Adressen der Session Host VMs"
  value       = azurerm_network_interface.sessionhost[*].private_ip_address
}

output "sessionhost_ids" {
  description = "Resource IDs der Session Host VMs"
  value       = azurerm_windows_virtual_machine.sessionhost[*].id
}
