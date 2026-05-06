# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 2: Cloud Connector Installation
# Installiert cwcconnector.exe auf den CC-VMs via WinRM (null_resource)
# Registriert CCs mit Citrix Cloud
# Status: SCAFFOLD
#
# WICHTIG: Dieses Modul muss von der Admin-VM (VID-TF-Admin) ausgeführt werden,
# da WinRM-Verbindungen über das Internet ein Sicherheitsrisiko darstellen.
# Admin-VM IP aus Modul 1 Outputs verwenden.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    citrix = {
      source  = "registry.terraform.io/citrix/citrix"
      version = "~> 1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

provider "citrix" {
  customer_id   = var.citrix_customer_id
  client_id     = var.citrix_client_id
  client_secret = var.citrix_client_secret
  environment   = var.citrix_cloud_environment
}
