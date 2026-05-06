# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 2: Variablen
# ─────────────────────────────────────────────────────────────────────────────

variable "citrix_customer_id"       { type = string; sensitive = true }
variable "citrix_client_id"         { type = string; sensitive = true }
variable "citrix_client_secret"     { type = string; sensitive = true }
variable "citrix_cloud_environment" { type = string; default = "eu" }

variable "resource_location_name"        { type = string; default = "VID-vSphere-RL" }
variable "resource_location_description" { type = string; default = "VID Resource Location – vSphere 8" }

# IPs der CC-VMs aus Modul 1 Outputs (manuell übertragen oder via terraform_remote_state)
variable "cc_vm_ips" {
  type        = list(string)
  description = "IP-Adressen der CC-VMs (aus Modul 1 outputs.cc_vm_ips)"
}

variable "provisioner_admin_user" {
  type        = string
  description = "Domain Admin für WinRM-Verbindung (DOMAIN\\User)"
  sensitive   = true
}
variable "provisioner_admin_password" {
  type      = string
  sensitive = true
}

# Software-URLs (Azure Blob Storage, SMB-Share via HTTP, o.ä.)
variable "cc_installer_url" {
  type        = string
  description = "Download-URL für cwcconnector.exe"
  # Beispiel: https://storageaccount.blob.core.windows.net/tfdata/cwcconnector.exe
}
variable "citrix_posh_sdk_url" {
  type        = string
  description = "Download-URL für CitrixPoshSdk.exe"
}
