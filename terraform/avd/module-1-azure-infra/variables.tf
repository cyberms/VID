# ─────────────────────────────────────────────────────────────────────────────
# VID – AVD, Modul 1: Variablen
# Status: SCAFFOLD / FUTURE PHASE
# ─────────────────────────────────────────────────────────────────────────────

# Azure Authentication (Service Principal)
variable "azure_subscription_id" { type = string; sensitive = true }
variable "azure_tenant_id"       { type = string; sensitive = true }
variable "azure_client_id"       { type = string; sensitive = true }
variable "azure_client_secret"   { type = string; sensitive = true }

# Umgebung
variable "environment"    { type = string; default = "prod" }   # prod, dev, test
variable "location"       { type = string; default = "germanywestcentral" }
variable "location_short" { type = string; default = "gwc" }    # für Ressourcennamen

# Naming
variable "prefix" { type = string; default = "vid" }

# Netzwerk
variable "vnet_address_space"        { type = string; default = "10.10.0.0/16" }
variable "subnet_sessionhosts_cidr"  { type = string; default = "10.10.1.0/24" }
variable "subnet_mgmt_cidr"          { type = string; default = "10.10.2.0/24" }

# DNS (für Hybrid Join)
variable "dns_servers" {
  type        = list(string)
  description = "DNS-Server (On-Prem DC IPs für Hybrid Join, oder Azure DNS für Azure AD Join)"
  default     = []
}

# Tags
variable "tags" {
  type = map(string)
  default = {
    Project     = "VID"
    ManagedBy   = "Terraform"
    Environment = "prod"
  }
}
