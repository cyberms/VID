# Outputs für Modul 2 (module-2-install)

output "cc_vm_ips" {
  description = "IP-Adressen der Cloud Connector VMs (für Modul 2 WinRM)"
  value       = vsphere_virtual_machine.cloud_connector[*].default_ip_address
}

output "cc_vm_names" {
  description = "Namen der Cloud Connector VMs"
  value       = vsphere_virtual_machine.cloud_connector[*].name
}

output "admin_vm_ip" {
  description = "IP-Adresse der Admin-VM (für Modul 2 WinRM-Basis)"
  value       = vsphere_virtual_machine.admin_vm.default_ip_address
}
