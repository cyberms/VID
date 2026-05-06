# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 2: Variablen
# Status: SCAFFOLD / FUTURE PHASE
# ─────────────────────────────────────────────────────────────────────────────

# IPs aus Modul 1
variable "cs_vm_ips" {
  type        = list(string)
  description = "IP-Adressen der Connection Server VMs (aus module-1-vsphere outputs.cs_vm_ips)"
}

variable "cs_primary_ip" {
  type        = string
  description = "IP der primären Connection Server VM (aus module-1-vsphere outputs.cs_primary_ip)"
}

# WinRM Zugang (lokaler Admin auf den VMs)
variable "winrm_username" { type = string; sensitive = true }
variable "winrm_password" { type = string; sensitive = true }
variable "winrm_port"     { type = number; default = 5985 }
variable "winrm_https"    { type = bool;   default = false }

# Horizon Installer
variable "horizon_installer_url" {
  type        = string
  description = "Download-URL oder UNC-Pfad des VMware Horizon Connection Server Installers (.exe)"
  # z.B. "https://packages.corp.local/horizon/VMware-Horizon-Connection-Server-x86_64-8.12.0.exe"
}

variable "horizon_installer_args" {
  type        = string
  description = "Silent-Install-Argumente für den Connection Server Installer"
  default     = "/v\"/qn /norestart VDM_SERVER_TYPE=1 VDM_SERVER_INSTANCE_TYPE=1\""
  # VDM_SERVER_TYPE=1 = Standard Server
  # VDM_SERVER_INSTANCE_TYPE=1 = Erstes/Primary, =2 = Replica
}

variable "horizon_replica_installer_args" {
  type        = string
  description = "Silent-Install-Argumente für den Replica Connection Server"
  default     = "/v\"/qn /norestart VDM_SERVER_TYPE=1 VDM_SERVER_INSTANCE_TYPE=2\""
}

variable "horizon_initial_admin" {
  type        = string
  description = "AD-Gruppe oder User, der Horizon-Administrator wird (z.B. corp\\\\VID-HorizonAdmins)"
}

# Horizon Lizenz
variable "horizon_license_key" {
  type        = string
  sensitive   = true
  description = "VMware Horizon Lizenzschlüssel (optional, kann auch später gesetzt werden)"
  default     = ""
}
