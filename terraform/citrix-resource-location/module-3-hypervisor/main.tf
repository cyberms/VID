# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 3: Hypervisor Connection + Resource Pool
# Status: SCAFFOLD
#
# Erstellt in Citrix Cloud:
#   - citrix_hypervisor        → vSphere Hosting Connection
#   - citrix_hypervisor_resource_pool → Cluster/Resource Pool Mapping
#
# Nach diesem Modul: terraform/citrix/ (Machine Catalog + Delivery Group)
# ─────────────────────────────────────────────────────────────────────────────

resource "citrix_hypervisor" "vsphere" {
  name               = var.hypervisor_name
  zone_id            = var.resource_location_id   # aus Modul 2 Output
  connection_type    = "VCenter"

  user_name          = var.vsphere_user
  password           = var.vsphere_password
  addresses          = [var.vsphere_server]

  ssl_thumbprint     = var.vsphere_ssl_thumbprint  # Optional: SSL-Fingerprint
}

resource "citrix_hypervisor_resource_pool" "vsphere_pool" {
  name                = var.resource_pool_name
  hypervisor          = citrix_hypervisor.vsphere.id

  # vSphere-spezifisch: Datacenter → Cluster → Resource Pool
  cluster {
    datacenter   = var.vsphere_datacenter_path
    cluster_name = var.vsphere_cluster_name
    host         = ""  # leer = gesamter Cluster
  }

  networks    = var.vsphere_networks
  storage     = var.vsphere_datastores
  temporary_storage = var.vsphere_temp_datastore

  use_local_storage_caching = false
}
