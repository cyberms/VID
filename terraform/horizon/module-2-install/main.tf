# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 2: Horizon Connection Server Installation via WinRM
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Installiert auf den VMs aus Modul 1:
#   - Horizon Connection Server (Primary) auf cs_vm_ips[0]
#   - Horizon Connection Server (Replica) auf cs_vm_ips[1..n]
#
# Voraussetzung: WinRM auf VMs aktiviert (via run_once_command_list in Modul 1)
# ─────────────────────────────────────────────────────────────────────────────

locals {
  replica_ips = slice(var.cs_vm_ips, 1, length(var.cs_vm_ips))
}

# ── Primary Connection Server ─────────────────────────────────────────────────
resource "null_resource" "horizon_cs_primary" {
  connection {
    type     = "winrm"
    host     = var.cs_primary_ip
    user     = var.winrm_username
    password = var.winrm_password
    port     = var.winrm_port
    https    = var.winrm_https
    insecure = true
    timeout  = "30m"
  }

  # Installer herunterladen
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -Command \"Invoke-WebRequest -Uri '${var.horizon_installer_url}' -OutFile 'C:\\\\Temp\\\\HorizonCS.exe' -UseBasicParsing\"",
    ]
  }

  # Primary installieren
  provisioner "remote-exec" {
    inline = [
      "cmd.exe /c mkdir C:\\Temp",
      "C:\\Temp\\HorizonCS.exe ${var.horizon_installer_args}",
    ]
  }
}

# ── Replica Connection Server(s) ─────────────────────────────────────────────
resource "null_resource" "horizon_cs_replica" {
  count = length(local.replica_ips)

  depends_on = [null_resource.horizon_cs_primary]

  connection {
    type     = "winrm"
    host     = local.replica_ips[count.index]
    user     = var.winrm_username
    password = var.winrm_password
    port     = var.winrm_port
    https    = var.winrm_https
    insecure = true
    timeout  = "30m"
  }

  provisioner "remote-exec" {
    inline = [
      "cmd.exe /c mkdir C:\\Temp",
      "powershell.exe -Command \"Invoke-WebRequest -Uri '${var.horizon_installer_url}' -OutFile 'C:\\\\Temp\\\\HorizonCS.exe' -UseBasicParsing\"",
      # VDM_INITIAL_ADMIN_SID und VDM_SERVER_INSTANCE_TYPE=2 (Replica) + Primary-IP angeben
      "C:\\Temp\\HorizonCS.exe ${var.horizon_replica_installer_args} VDM_SERVER_NAME=${var.cs_primary_ip}",
    ]
  }
}
