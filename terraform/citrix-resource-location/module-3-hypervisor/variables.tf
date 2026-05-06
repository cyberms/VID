variable "citrix_customer_id"       { type = string; sensitive = true }
variable "citrix_client_id"         { type = string; sensitive = true }
variable "citrix_client_secret"     { type = string; sensitive = true }
variable "citrix_cloud_environment" { type = string; default = "eu" }

# Resource Location ID aus Modul 2
variable "resource_location_id" {
  type        = string
  description = "ID der Resource Location (aus module-2-install outputs.resource_location_id)"
}

# vSphere Hosting Connection
variable "hypervisor_name"        { type = string; default = "vSphere-euc-demo" }
variable "vsphere_server"         { type = string }
variable "vsphere_user"           { type = string; sensitive = true }
variable "vsphere_password"       { type = string; sensitive = true }
variable "vsphere_ssl_thumbprint" { type = string; default = "" }

variable "vsphere_datacenter_path" { type = string }  # z.B. "Datacenter"
variable "vsphere_cluster_name"    { type = string }  # z.B. "cluster01"

variable "resource_pool_name" { type = string; default = "VID-vSphere-Pool" }

variable "vsphere_networks" {
  type        = list(string)
  description = "Liste der vSphere Netzwerke/Portgroups für den Resource Pool"
}
variable "vsphere_datastores" {
  type        = list(string)
  description = "Liste der Datastores für MCS-VMs"
}
variable "vsphere_temp_datastore" {
  type        = string
  description = "Temporärer Datastore für MCS-Prep"
}
