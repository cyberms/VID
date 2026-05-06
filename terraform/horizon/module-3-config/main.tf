# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 3: Horizon Konfiguration via REST API (PowerShell)
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Da kein offizieller Terraform-Provider für Horizon existiert, wird die
# Konfiguration via Horizon REST API (PowerShell) durchgeführt.
#
# Geplante Konfigurationsschritte:
#   1. vCenter als vSphere-Hosting hinzufügen
#   2. Instant Clone Domain Account konfigurieren
#   3. Desktop Pool (Instant Clone) anlegen
#   4. Pool-Entitlement setzen (AD-Gruppe)
#
# Für Phase 3+ empfohlen: Ansible VMware Horizon Collection
#   https://galaxy.ansible.com/community/vmware
# ─────────────────────────────────────────────────────────────────────────────

# ── Horizon REST API: vSphere Hosting konfigurieren ──────────────────────────
resource "null_resource" "horizon_vcenter_config" {
  connection {
    type     = "winrm"
    host     = var.horizon_primary_ip
    user     = var.horizon_admin_user
    password = var.horizon_admin_password
    https    = false
    insecure = true
    timeout  = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      # Horizon REST API: vCenter hinzufügen (vereinfachtes Beispiel)
      "powershell.exe -Command \"",
      "$headers = @{ 'Content-Type' = 'application/json' }",
      "$body = @{ vcenter_host = '${var.vcenter_server}'; username = '${var.vcenter_user}'; password = '${var.vcenter_password}' } | ConvertTo-Json",
      "# TODO: Token-basierte Auth gegen Horizon REST API implementieren",
      "# Invoke-RestMethod -Uri 'https://localhost/rest/config/v1/virtual-centers' -Method POST -Headers $headers -Body $body",
      "Write-Host 'SCAFFOLD: vCenter-Konfiguration noch nicht implementiert'",
      "\"",
    ]
  }
}

# ── Horizon REST API: Desktop Pool anlegen ───────────────────────────────────
resource "null_resource" "horizon_desktop_pool" {
  depends_on = [null_resource.horizon_vcenter_config]

  connection {
    type     = "winrm"
    host     = var.horizon_primary_ip
    user     = var.horizon_admin_user
    password = var.horizon_admin_password
    https    = false
    insecure = true
    timeout  = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -Command \"Write-Host 'SCAFFOLD: Desktop Pool ${var.pool_name} noch nicht implementiert'\"",
      # TODO: Horizon REST API POST /rest/inventory/v1/desktop-pools
    ]
  }
}
