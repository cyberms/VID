# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 2: Cloud Connector Software-Installation
# Status: SCAFFOLD
#
# Ablauf:
#   1. Citrix Cloud Resource Location anlegen (citrix Provider)
#   2. cwcconnector.exe + CitrixPoshSdk.exe auf CC-VMs kopieren (WinRM)
#   3. Cloud Connector Software installieren + mit Citrix Cloud registrieren
# ─────────────────────────────────────────────────────────────────────────────

# ── Resource Location in Citrix Cloud anlegen ─────────────────────────────────

resource "citrix_zone" "resource_location" {
  name        = var.resource_location_name
  description = var.resource_location_description
}

# ── Cloud Connector auf CC-VM-01 installieren ─────────────────────────────────

resource "null_resource" "install_cc" {
  count = length(var.cc_vm_ips)

  connection {
    type     = "winrm"
    host     = var.cc_vm_ips[count.index]
    user     = var.provisioner_admin_user
    password = var.provisioner_admin_password
    port     = 5985
    https    = false
    insecure = true
    timeout  = "10m"
  }

  # cwcconnector.exe vom Storage herunterladen
  provisioner "remote-exec" {
    inline = [
      # Installer herunterladen
      "powershell.exe -Command \"Invoke-WebRequest -Uri '${var.cc_installer_url}' -OutFile 'C:\\Temp\\cwcconnector.exe' -UseBasicParsing\"",

      # Citrix Remote PowerShell SDK herunterladen
      "powershell.exe -Command \"Invoke-WebRequest -Uri '${var.citrix_posh_sdk_url}' -OutFile 'C:\\Temp\\CitrixPoshSdk.exe' -UseBasicParsing\"",

      # SDK installieren (silent)
      "cmd.exe /C C:\\Temp\\CitrixPoshSdk.exe /q /norestart",

      # Cloud Connector installieren und mit Citrix Cloud registrieren
      "powershell.exe -Command \"& 'C:\\Temp\\cwcconnector.exe' /q /customerid:'${var.citrix_customer_id}' /clientid:'${var.citrix_client_id}' /clientsecret:'${var.citrix_client_secret}' /location:'${citrix_zone.resource_location.id}' /acceptTermsOfService:true\""
    ]
  }

  depends_on = [citrix_zone.resource_location]
}
