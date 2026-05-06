# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 1: Variablen
# ─────────────────────────────────────────────────────────────────────────────

# ── vSphere Verbindung ────────────────────────────────────────────────────────
variable "vsphere_server" {
  type        = string
  description = "vCenter Server FQDN oder IP"
}
variable "vsphere_user" {
  type        = string
  description = "vCenter Benutzername (z.B. administrator@vsphere.local)"
  sensitive   = true
}
variable "vsphere_password" {
  type        = string
  description = "vCenter Passwort"
  sensitive   = true
}
variable "vsphere_allow_unverified_ssl" {
  type        = bool
  description = "SSL-Zertifikat-Validierung überspringen (nur für Labs)"
  default     = false
}

# ── vSphere Infrastruktur ─────────────────────────────────────────────────────
variable "datacenter" {
  type        = string
  description = "vSphere Datacenter Name"
}
variable "cluster" {
  type        = string
  description = "vSphere Cluster Name"
}
variable "datastore" {
  type        = string
  description = "vSphere Datastore für CC-VMs"
}
variable "network" {
  type        = string
  description = "vSphere Portgroup/Network für CC-VMs"
}
variable "vm_folder" {
  type        = string
  description = "vSphere VM-Ordner für CC-VMs"
  default     = "Citrix/CloudConnectors"
}

# ── Template / ISO ───────────────────────────────────────────────────────────
variable "template_name" {
  type        = string
  description = "Windows Server 2022 Template Name in vSphere (Domain-joined)"
}

# ── Cloud Connector VMs ───────────────────────────────────────────────────────
variable "cc_vm_count" {
  type        = number
  description = "Anzahl Cloud Connector VMs (mindestens 2 für HA)"
  default     = 2
}
variable "cc_vm_name_prefix" {
  type        = string
  description = "Präfix für CC-VM-Namen (z.B. 'VID-CC' → VID-CC-01, VID-CC-02)"
  default     = "VID-CC"
}
variable "cc_cpu_count" {
  type        = number
  description = "vCPUs pro CC-VM (Citrix empfiehlt min. 2)"
  default     = 2
}
variable "cc_memory_mb" {
  type        = number
  description = "RAM pro CC-VM in MB (Citrix empfiehlt min. 4096)"
  default     = 4096
}

# ── Admin-VM (für Modul 2 WinRM-Provisioning) ────────────────────────────────
variable "admin_vm_name" {
  type        = string
  description = "Name der Admin-VM (wird für Modul 2 WinRM-Verbindung benötigt)"
  default     = "VID-TF-Admin"
}
variable "admin_cpu_count" {
  type    = number
  default = 2
}
variable "admin_memory_mb" {
  type    = number
  default = 4096
}

# ── Active Directory ──────────────────────────────────────────────────────────
variable "domain" {
  type        = string
  description = "AD-Domain für Domain-Join (z.B. corp.example.com)"
}
variable "domain_admin_user" {
  type        = string
  description = "Domain Admin für Domain-Join und Modul 2 WinRM"
  sensitive   = true
}
variable "domain_admin_password" {
  type        = string
  description = "Domain Admin Passwort"
  sensitive   = true
}
variable "cc_ou" {
  type        = string
  description = "OU für CC-Computer-Objekte"
  default     = "OU=CloudConnectors,OU=Citrix,DC=corp,DC=example,DC=com"
}
