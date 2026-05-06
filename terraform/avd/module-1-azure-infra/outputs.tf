output "resource_group_name" {
  description = "Name der AVD Resource Group → in module-2-hostpool als resource_group_name eintragen"
  value       = azurerm_resource_group.avd.name
}

output "resource_group_id" {
  description = "ID der AVD Resource Group"
  value       = azurerm_resource_group.avd.id
}

output "vnet_id" {
  description = "ID des AVD Virtual Network"
  value       = azurerm_virtual_network.avd.id
}

output "subnet_sessionhosts_id" {
  description = "ID des Session Host Subnets → in module-3-sessionhosts als subnet_id eintragen"
  value       = azurerm_subnet.sessionhosts.id
}

output "location" {
  description = "Azure Region"
  value       = azurerm_resource_group.avd.location
}
