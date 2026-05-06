# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 3: Variablen
# Status: SCAFFOLD / FUTURE PHASE
# ─────────────────────────────────────────────────────────────────────────────

# Connection Server aus Modul 2
variable "horizon_primary_ip" {
  type        = string
  description = "IP des primären Horizon Connection Server (aus module-2-install)"
}

# Horizon Admin-Credentials (AD-Account mit Horizon Admin-Rechten)
variable "horizon_admin_user"     { type = string; sensitive = true }
variable "horizon_admin_password" { type = string; sensitive = true }
variable "horizon_domain"         { type = string }  # z.B. "corp"

# vSphere Hosting (für Desktop Pool Konfiguration)
variable "vcenter_server"   { type = string }
variable "vcenter_user"     { type = string; sensitive = true }
variable "vcenter_password" { type = string; sensitive = true }

variable "vsphere_datacenter"         { type = string }
variable "vsphere_cluster"            { type = string }
variable "vsphere_datastore_path"     { type = string }
variable "vsphere_network"            { type = string }
variable "vsphere_parent_vm"          { type = string; description = "Packer-gebautes Golden Image" }
variable "vsphere_snapshot_name"      { type = string; default = "VID-IC-Snapshot" }

# Desktop Pool
variable "pool_name"                  { type = string; default = "VID-Pool-W11" }
variable "pool_display_name"          { type = string; default = "VID Windows 11 Pool" }
variable "pool_vm_count"              { type = number; default = 10 }
variable "pool_vm_name_prefix"        { type = string; default = "VID-W11" }
variable "pool_ad_container"          { type = string; description = "AD OU für Pool-VMs" }

# Entitlement
variable "pool_entitlement_group"     { type = string; description = "AD-Gruppe für Pool-Zugriff" }

# AD-Domain für Machine Account
variable "ad_domain_fqdn"             { type = string }
variable "ad_svc_account"             { type = string; sensitive = true }
variable "ad_svc_password"            { type = string; sensitive = true }
