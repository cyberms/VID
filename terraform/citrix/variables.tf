# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1b: Variablen
# Werte in terraform.tfvars (nicht im Repo!) oder via TF_VAR_* Umgebungsvariablen
# ─────────────────────────────────────────────────────────────────────────────

# ── Citrix Cloud Authentifizierung ───────────────────────────────────────────

variable "citrix_customer_id" {
  type        = string
  description = "Citrix Cloud Customer ID (Citrix Cloud Console → Identity → API Access)"
  sensitive   = true
}

variable "citrix_client_id" {
  type        = string
  description = "Citrix Cloud Secure Client ID (API Key)"
  sensitive   = true
}

variable "citrix_client_secret" {
  type        = string
  description = "Citrix Cloud Secure Client Secret"
  sensitive   = true
}

variable "citrix_cloud_environment" {
  type        = string
  description = "Citrix Cloud Region: 'us', 'eu', 'ap-s', 'jp'"
  default     = "eu"
}

# ── Citrix DaaS – Zone / Resource Location ───────────────────────────────────

variable "citrix_zone_id" {
  type        = string
  description = "ID der Citrix DaaS Zone (Resource Location). Abrufbar mit: Get-ConfigZone | Select Name, Id"
}

# ── vSphere Hosting Connection (bereits in Citrix DaaS konfiguriert) ─────────

variable "hypervisor_id" {
  type        = string
  description = "ID der vSphere Hosting Connection in Citrix DaaS. Abrufbar mit: Get-HypHypervisorConnection | Select Name, Id"
}

variable "hypervisor_resource_pool_id" {
  type        = string
  description = "ID des Hypervisor Resource Pool (Cluster/Host). Abrufbar mit: Get-HypHypervisorResourcePool | Select Name, Id"
}

# ── Master Image (wird bei jedem Packer-Build aktualisiert) ──────────────────

variable "master_image_vm" {
  type        = string
  description = <<-EOT
    Vollständiger XDHyp-Pfad zum Master Image (VM + Snapshot), z.B.:
    XDHyp:\Connections\vSphere-euc-demo\Datacenter.datacenter\cluster01.cluster\windows-desktop-11-vid.vm\packer-snapshot.snapshot

    Wird bei jedem neuen Packer-Build via terraform apply -var="master_image_vm=..." aktualisiert.
    Lässt sich auch aus dem Packer-Manifest ableiten (update-image.sh).
  EOT
}

# ── Netzwerk ──────────────────────────────────────────────────────────────────

variable "network_path" {
  type        = string
  description = <<-EOT
    XDHyp-Pfad zum vSphere Netzwerk/Portgroup, z.B.:
    XDHyp:\Connections\vSphere-euc-demo\Datacenter.datacenter\network\VDI-VLAN100.network
  EOT
}

# ── Machine Catalog ───────────────────────────────────────────────────────────

variable "catalog_name" {
  type        = string
  description = "Name des Machine Catalogs in Citrix DaaS"
  default     = "VID-W11-MCS"
}

variable "catalog_description" {
  type        = string
  description = "Beschreibung des Machine Catalogs"
  default     = "Windows 11 VDI – Managed by Terraform / VID"
}

variable "vm_count" {
  type        = number
  description = "Anzahl der VMs im Catalog"
  default     = 5
}

variable "vm_naming_scheme" {
  type        = string
  description = "Namensschema für MCS-VMs. '##' bzw. '###' = fortlaufende Nummer, z.B. 'VID-W11-##' → VID-W11-01, VID-W11-02 ..."
  default     = "VID-W11-##"
}

variable "vm_cpu_count" {
  type        = number
  description = "Anzahl vCPUs pro VM"
  default     = 4
}

variable "vm_memory_mb" {
  type        = number
  description = "RAM pro VM in MB"
  default     = 4096
}

variable "writeback_cache_disk_gb" {
  type        = number
  description = "Write-Back-Cache Diskgröße in GB (nur bei MCS I/O Optimization). 0 = deaktiviert"
  default     = 15
}

variable "writeback_cache_memory_mb" {
  type        = number
  description = "Write-Back-Cache RAM in MB (nur bei MCS I/O Optimization). 0 = deaktiviert"
  default     = 256
}

variable "storage_type" {
  type        = string
  description = "Storage-Typ für MCS-VMs. 'DifferentDataStore' = Linked Clones auf separatem Datastore"
  default     = "DifferentDataStore"
}

# ── Active Directory ──────────────────────────────────────────────────────────

variable "domain" {
  type        = string
  description = "Active Directory Domain, z.B. 'corp.example.com'"
}

variable "domain_ou" {
  type        = string
  description = "OU für MCS-Computer-Objekte, z.B. 'OU=VDI-Desktops,OU=VID,DC=corp,DC=example,DC=com'"
}

# ── Delivery Group ────────────────────────────────────────────────────────────

variable "delivery_group_name" {
  type        = string
  description = "Name der Delivery Group in Citrix DaaS"
  default     = "VID-W11-Desktop-Pool"
}

variable "delivery_group_description" {
  type        = string
  description = "Beschreibung der Delivery Group"
  default     = "Windows 11 Desktop Pool – Managed by Terraform / VID"
}

variable "desktop_published_name" {
  type        = string
  description = "Anzeigename des Desktops für Endbenutzer (in Citrix Workspace)"
  default     = "Windows 11 Desktop"
}

variable "user_groups" {
  type        = list(string)
  description = "Liste der AD-Gruppen (SAMAccountName oder UPN) die Zugriff auf die Delivery Group erhalten"
  default     = []
  # Beispiel: ["CORP\\Citrix-Desktop-Users", "CORP\\VDI-Piloten"]
}
