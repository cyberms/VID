# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 1: Variablen
# Status: SCAFFOLD / FUTURE PHASE
# ─────────────────────────────────────────────────────────────────────────────

# vSphere Connection
variable "vsphere_server"               { type = string }
variable "vsphere_user"                 { type = string; sensitive = true }
variable "vsphere_password"             { type = string; sensitive = true }
variable "vsphere_allow_unverified_ssl" { type = bool;   default = false }

# vSphere Topology
variable "vsphere_datacenter"  { type = string }            # z.B. "Datacenter"
variable "vsphere_cluster"     { type = string }            # z.B. "cluster01"
variable "vsphere_datastore"   { type = string }            # z.B. "datastore01"
variable "vsphere_network"     { type = string }            # z.B. "VM Network"
variable "vsphere_folder"      { type = string; default = "VID/Horizon" }

# VM Template (Windows Server 2022 mit WinRM aktiviert)
variable "template_name"       { type = string }            # z.B. "WS2022-Template"

# Horizon Connection Server VMs
variable "cs_vm_count"         { type = number; default = 2 }
variable "cs_vm_name_prefix"   { type = string; default = "VID-HCS" }
variable "cs_num_cpus"         { type = number; default = 4 }
variable "cs_memory_mb"        { type = number; default = 8192 }
variable "cs_disk_size_gb"     { type = number; default = 80 }

variable "cs_ip_addresses" {
  type        = list(string)
  description = "Statische IPs für Connection Server VMs (z.B. [\"10.0.1.30\", \"10.0.1.31\"])"
}
variable "cs_netmask"          { type = string }
variable "cs_gateway"          { type = string }
variable "cs_dns_servers"      { type = list(string) }

# Active Directory
variable "ad_domain"           { type = string }            # z.B. "corp.local"
variable "ad_join_user"        { type = string; sensitive = true }
variable "ad_join_password"    { type = string; sensitive = true }
variable "ad_ou_path"          { type = string; default = "" }  # leer = default Computers OU

# Lokaler Admin auf den VMs
variable "vm_admin_username"   { type = string; sensitive = true }
variable "vm_admin_password"   { type = string; sensitive = true }
