output "hypervisor_id" {
  description = "ID der Hypervisor Connection → in terraform/citrix/terraform.tfvars als hypervisor_id eintragen"
  value       = citrix_hypervisor.vsphere.id
}
output "hypervisor_resource_pool_id" {
  description = "ID des Hypervisor Resource Pool → in terraform/citrix/terraform.tfvars als hypervisor_resource_pool_id eintragen"
  value       = citrix_hypervisor_resource_pool.vsphere_pool.id
}
