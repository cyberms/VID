output "cs_vm_ips" {
  description = "IP-Adressen der Connection Server VMs → in module-2-install als cs_vm_ips eintragen"
  value       = vsphere_virtual_machine.horizon_cs[*].default_ip_address
}

output "cs_vm_names" {
  description = "Namen der Connection Server VMs"
  value       = vsphere_virtual_machine.horizon_cs[*].name
}

output "cs_primary_ip" {
  description = "IP der primären Connection Server VM (Index 0)"
  value       = vsphere_virtual_machine.horizon_cs[0].default_ip_address
}
