# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1b: Citrix DaaS Terraform Provider
# ─────────────────────────────────────────────────────────────────────────────
# Terraform-Provider: registry.terraform.io/citrix/citrix
# Docs:               https://registry.terraform.io/providers/citrix/citrix/latest
# Onboarding-Helper: https://github.com/citrix/terraform-provider-citrix/tree/main/scripts/onboarding-helper
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    citrix = {
      source  = "registry.terraform.io/citrix/citrix"
      version = "~> 1.0"
    }
  }

  # Empfehlung für Teamumgebungen: Remote State (Azure Blob, S3, Terraform Cloud)
  # backend "azurerm" {
  #   resource_group_name  = "rg-vid-terraform"
  #   storage_account_name = "stvidterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "citrix/daas.tfstate"
  # }
}

provider "citrix" {
  # Citrix Cloud (DaaS) – Authentication via Secure Client (API Key)
  # Werte aus terraform.tfvars oder Umgebungsvariablen:
  #   CITRIX_CUSTOMER_ID, CITRIX_CLIENT_ID, CITRIX_CLIENT_SECRET
  customer_id   = var.citrix_customer_id
  client_id     = var.citrix_client_id
  client_secret = var.citrix_client_secret

  # Citrix Cloud Region (default: US)
  # Für EU-Kunden: "eu" setzen
  # Mögliche Werte: "us", "eu", "ap-s", "jp"
  environment = var.citrix_cloud_environment
}
