# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 1: vSphere VMs für Horizon Connection Server
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.7.0"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}
