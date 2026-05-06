# ─────────────────────────────────────────────────────────────────────────────
# VID – AVD, Modul 2: Variablen
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

# Host Pool
variable "hostpool_name"         { type = string; default = "hp-vid-w11-pool" }
variable "hostpool_friendly_name"{ type = string; default = "VID Windows 11 Pool" }
variable "hostpool_type"         {
  type    = string
  default = "Pooled"         # Pooled oder Personal
}
variable "hostpool_load_balancer_type" {
  type    = string
  default = "BreadthFirst"   # BreadthFirst oder DepthFirst
}
variable "hostpool_max_sessions_per_host" {
  type    = number
  default = 10
}
variable "hostpool_start_vm_on_connect" {
  type    = bool
  default = true             # Start VM on Connect für Energieeinsparung
}

# Workspace
variable "workspace_name"         { type = string; default = "ws-vid" }
variable "workspace_friendly_name"{ type = string; default = "VID Workspace" }

# Application Groups
variable "dag_name"   { type = string; default = "dag-vid-desktop" }   # Desktop App Group
variable "rag_name"   { type = string; default = "rag-vid-apps" }      # RemoteApp Group (optional)
variable "create_rag" { type = bool;   default = false }

# RBAC: AAD-Gruppe für Desktop Virtualization User
variable "avd_users_group_name" {
  type        = string
  description = "Name der AAD-Gruppe mit AVD-Nutzern (wird Desktop Virtualization User Role zugewiesen)"
}

# Tags
variable "tags" {
  type    = map(string)
  default = { Project = "VID", ManagedBy = "Terraform" }
}
