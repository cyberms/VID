// ─────────────────────────────────────────────────────────────────────────────
// VID Windows 11 AVD Template – Variables
// Packer Builder: azure-arm
// ─────────────────────────────────────────────────────────────────────────────

// ── Azure Authentication ──────────────────────────────────────────────────────
// Werte in build.pkrvars.hcl (nicht im Repo!)
// Empfohlen: Service Principal mit Contributor-Rechten auf Build-RG und Gallery-RG

variable "azure_client_id" {
  type        = string
  description = "Azure App Registration – Client (Application) ID"
  sensitive   = true
}

variable "azure_client_secret" {
  type        = string
  description = "Azure App Registration – Client Secret"
  sensitive   = true
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure Active Directory Tenant ID"
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure Subscription ID für Build und Gallery"
}

// ── Azure Location & Resource Groups ─────────────────────────────────────────

variable "azure_location" {
  type        = string
  description = "Azure Region für Build-VM (z.B. 'westeurope')"
  default     = "westeurope"
}

variable "azure_vm_size" {
  type        = string
  description = "VM-Größe für den Packer Build (z.B. 'Standard_D4s_v5')"
  default     = "Standard_D4s_v5"
}

variable "azure_build_resource_group" {
  type        = string
  description = "Resource Group für Build-VM und temporäre Ressourcen"
}

variable "azure_build_storage_account" {
  type        = string
  description = "Storage Account für Build-Artefakte (in azure_build_resource_group)"
}

variable "azure_temp_resource_group" {
  type        = string
  description = "Temporäre Resource Group – wird nach Build automatisch gelöscht"
  default     = "rg-vid-packer-temp"
}

// ── Azure Compute Gallery (Shared Image Gallery) ──────────────────────────────

variable "azure_gallery_resource_group" {
  type        = string
  description = "Resource Group der Azure Compute Gallery"
}

variable "azure_gallery_name" {
  type        = string
  description = "Name der Azure Compute Gallery (z.B. 'gal_vid_images')"
}

variable "azure_gallery_image_name" {
  type        = string
  description = "Image-Definition in der Gallery (z.B. 'VID-W11-AVD-SingleSession')"
  default     = "VID-W11-AVD-SingleSession"
}

variable "azure_gallery_replication_regions" {
  type        = list(string)
  description = "Azure-Regionen für Image-Replikation"
  default     = ["westeurope"]
}

// ── OS Disk ───────────────────────────────────────────────────────────────────

variable "vm_guest_os_name" {
  type        = string
  description = "OS-Name für Namensgebung (z.B. 'w11')"
  default     = "w11"
}

variable "vm_disk_size_gb" {
  type        = number
  description = "OS-Disk Größe in GB"
  default     = 128
}

// ── Build Credentials ─────────────────────────────────────────────────────────
// Werte in build.pkrvars.hcl (nicht im Repo!)

variable "build_username" {
  type        = string
  description = "Lokaler Admin-Username für den Build (WinRM)"
  sensitive   = true
}

variable "build_password" {
  type        = string
  description = "Lokaler Admin-Passwort für den Build (WinRM)"
  sensitive   = true
}

// ── VID-Data SMB (optional für AVD – kann auch direkt aus Internet laden) ─────

variable "vid_smb_server" {
  type        = string
  description = "UNC-Servername des VID-Data SMB-Shares (optional bei Azure, wenn PSADT-Pakete auf Share liegen)"
  default     = ""
}

variable "vid_smb_share" {
  type        = string
  description = "SMB Share-Name"
  default     = "VID-Data"
}

variable "vid_smb_username" {
  type        = string
  description = "Service Account für SMB-Zugriff"
  sensitive   = true
  default     = ""
}

variable "vid_smb_password" {
  type        = string
  description = "Passwort für SMB-Zugriff"
  sensitive   = true
  default     = ""
}

// ── VID Broker ────────────────────────────────────────────────────────────────
// Für dieses Template immer "avd"

variable "vid_broker" {
  type        = string
  description = "VDI Broker – für dieses Template immer 'avd'"
  default     = "avd"

  validation {
    condition     = var.vid_broker == "avd"
    error_message = "Dieses Template ist für vid_broker = 'avd'. Für Citrix: windows/desktop/11/, für Horizon: windows/desktop/11/ (vid_broker=horizon)."
  }
}
