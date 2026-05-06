# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 3: Horizon Konfiguration (Pools, Farms, Entitlements)
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Hinweis: Es gibt keinen offiziellen Terraform-Provider für VMware Horizon.
# Optionen:
#   a) PowerShell + VMware PowerCLI / Horizon REST API (via null_resource)
#   b) Community-Provider: terraform-provider-horizon (inoffiziell)
#   c) Ansible VMware Horizon Collection (empfohlen für Phase 3+)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
