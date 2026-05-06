# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1b: Outputs
# ─────────────────────────────────────────────────────────────────────────────

output "catalog_id" {
  description = "ID des Machine Catalogs (für Terraform-Referenzen oder Citrix DaaS API)"
  value       = citrix_machine_catalog.vid_w11.id
}

output "catalog_name" {
  description = "Name des Machine Catalogs"
  value       = citrix_machine_catalog.vid_w11.name
}

output "delivery_group_id" {
  description = "ID der Delivery Group"
  value       = citrix_delivery_group.vid_w11.id
}

output "delivery_group_name" {
  description = "Name der Delivery Group"
  value       = citrix_delivery_group.vid_w11.name
}

output "master_image_vm" {
  description = "Aktuell verwendetes Master Image (XDHyp-Pfad)"
  value       = var.master_image_vm
}

output "vm_count" {
  description = "Anzahl provisionierter VMs im Catalog"
  value       = var.vm_count
}
