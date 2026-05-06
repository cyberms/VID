# ─────────────────────────────────────────────────────────────────────────────
# VID – AVD, Modul 3: Variablen
# Status: SCAFFOLD / FUTURE PHASE
# ─────────────────────────────────────────────────────────────────────────────

# Azure Authentication
variable "azure_subscription_id" { type = string; sensitive = true }
variable "azure_tenant_id"       { type = string; sensitive = true }
variable "azure_client_id"       { type = string; sensitive = true }
variable "azure_client_secret"   { type = string; sensitive = true }

# Aus Modul 1
variable "resource_group_name"   { type = string }
variable "location"              { type = string }
variable "subnet_id"             { type = string; description = "ID des Session Host Subnets (aus module-1-azure-infra)" }

# Aus Modul 2
variable "hostpool_name"         { type = string }
variable "registration_token"    { type = string; sensitive = true; description = "AVD Registration Token (aus module-2-hostpool)" }

# Session Host VMs
variable "vm_count"              { type = number; default = 5 }
variable "vm_name_prefix"        { type = string; default = "vidavd" }
variable "vm_size"               { type = string; default = "Standard_D4s_v5" }

# Image (Packer-gebautes VID-Image aus Azure Compute Gallery oder als managed image)
variable "image_source"          {
  type        = string
  default     = "gallery"          # "gallery" oder "managed_image"
}
variable "gallery_resource_group"{ type = string; default = "" }
variable "gallery_name"          { type = string; default = "" }
variable "gallery_image_name"    { type = string; default = "VID-W11-AVD" }
variable "gallery_image_version" { type = string; default = "latest" }

variable "managed_image_id"      { type = string; default = "" }  # wenn image_source = "managed_image"

# OS Disk
variable "os_disk_type"          { type = string; default = "Premium_LRS" }
variable "os_disk_size_gb"       { type = number; default = 128 }

# Admin Credentials (für Initial Setup – wird nach Domain Join nicht mehr benötigt)
variable "vm_admin_username"     { type = string; sensitive = true }
variable "vm_admin_password"     { type = string; sensitive = true }

# Domain Join
variable "domain_join_type"      {
  type    = string
  default = "hybrid"              # "hybrid" (ADDS) oder "aadj" (Azure AD Join / Entra ID)
}
variable "domain_fqdn"           { type = string; default = "" }    # nur bei hybrid
variable "domain_ou_path"        { type = string; default = "" }    # z.B. "OU=AVD,OU=VID,DC=corp,DC=local"
variable "domain_join_username"  { type = string; sensitive = true; default = "" }
variable "domain_join_password"  { type = string; sensitive = true; default = "" }

# Tags
variable "tags" {
  type    = map(string)
  default = { Project = "VID", ManagedBy = "Terraform" }
}
