# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 1: vSphere VM-Erstellung
# Erstellt: CC-VMs (2x) + Admin-VM in vSphere 8
# Status: SCAFFOLD
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
