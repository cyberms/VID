# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 3: Hypervisor Connection + Resource Pool
# Legt die vSphere Hosting Connection in Citrix Cloud an.
# Status: SCAFFOLD
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    citrix = {
      source  = "registry.terraform.io/citrix/citrix"
      version = "~> 1.0"
    }
  }
}

provider "citrix" {
  customer_id   = var.citrix_customer_id
  client_id     = var.citrix_client_id
  client_secret = var.citrix_client_secret
  environment   = var.citrix_cloud_environment
}
