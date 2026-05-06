# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1b: Citrix DaaS Machine Catalog + Delivery Group
#
# Voraussetzungen (einmalig, außerhalb Terraform):
#   1. Citrix DaaS Zone / Resource Location konfiguriert
#   2. vSphere Hosting Connection in Citrix DaaS angelegt
#   3. Cloud Connector(s) im Resource Location installiert und verbunden
#   4. Packer-Build abgeschlossen → Master Image VM in vSphere vorhanden
#   5. Snapshot auf der Master Image VM erstellt
#
# Image-Update-Workflow (nach jedem Packer-Build):
#   ./update-image.sh   (liest Packer-Manifest, ruft terraform apply auf)
#   oder manuell:
#   terraform apply -var="master_image_vm=XDHyp:\Connections\...\.vm\snap.snapshot"
# ─────────────────────────────────────────────────────────────────────────────

# ── Machine Catalog ───────────────────────────────────────────────────────────
# Nicht-persistenter Desktop-Katalog (Random / Discard) mit MCS-Provisioning.
# VMs werden bei jedem Start aus dem Master Image neu erstellt.
# Write-Back-Cache (MCS I/O Optimization) reduziert Storage-IOPS.

resource "citrix_machine_catalog" "vid_w11" {
  name        = var.catalog_name
  description = var.catalog_description

  # Resource Location / Zone
  zone = var.citrix_zone_id

  # Nicht-persistente Desktops: Random = Zufällige Zuweisung, bei Abmeldung zurück in den Pool
  allocation_type = "Random"
  session_support = "SingleSession"

  # Machine Creation Services (MCS) – Linked Clones aus dem Master Image
  provisioning_type = "MCS"

  provisioning_scheme = {
    # vSphere Hosting Connection (bereits in Citrix DaaS konfiguriert)
    hypervisor               = var.hypervisor_id
    hypervisor_resource_pool = var.hypervisor_resource_pool_id

    # Master Image: XDHyp:\Connections\...\vm.vm\snapshot.snapshot
    # Dieser Wert wird bei jedem Packer-Build via terraform apply aktualisiert.
    machine_config = {
      master_image = var.master_image_vm
      memory_mb    = var.vm_memory_mb
      cpu_count    = var.vm_cpu_count
    }

    # Netzwerk-Mapping: Virtuelle NIC → vSphere Portgroup
    network_mapping = [
      {
        network_device = "0"
        network        = var.network_path
      }
    ]

    # Storage: Write-Back-Cache für MCS I/O Optimization
    # Reduziert IOPS auf dem Haupt-Datastore erheblich.
    storage_type                   = var.storage_type
    writeback_cache_disk_size_gb   = var.writeback_cache_disk_gb
    writeback_cache_memory_size_mb = var.writeback_cache_memory_mb

    # Active Directory – Computer-Konten und Namensschema
    machine_account_creation_rules = {
      naming_scheme      = var.vm_naming_scheme   # z.B. "VID-W11-##"
      naming_scheme_type = "Numeric"
      domain             = var.domain
      domain_ou          = var.domain_ou
    }

    # Anzahl der VMs im Catalog
    num_total_machines = var.vm_count
  }
}

# ── Delivery Group ────────────────────────────────────────────────────────────
# Verbindet den Machine Catalog mit Benutzern.
# Jede AD-Gruppe in var.user_groups erhält Zugriff auf den Desktop-Pool.

resource "citrix_delivery_group" "vid_w11" {
  name        = var.delivery_group_name
  description = var.delivery_group_description

  # Machine Catalogs: welche Kataloge und wie viele VMs dieser DG bereitstellt
  associated_machine_catalogs = [
    {
      machine_catalog = citrix_machine_catalog.vid_w11.id
      machine_count   = var.vm_count
    }
  ]

  # Desktop-Veröffentlichung (angezeigter Name in Citrix Workspace)
  desktops = [
    {
      published_name      = var.desktop_published_name
      enabled             = true
      session_reconnection = "Always"
    }
  ]

  # Benutzer / AD-Gruppen
  # Format: "DOMAIN\\Gruppe" oder "gruppe@domain.com"
  associated_users = var.user_groups

  # Automatischer Shutdown bei Abmeldung (nicht-persistent)
  # Spart Ressourcen: VMs werden heruntergefahren, nicht suspendiert
  autoscale_settings = {
    autoscale_enabled = true
    power_time_schemes = [
      {
        # Werktage: Geschäftszeiten
        days_of_week             = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        display_name             = "Weekdays"
        peak_time_ranges         = ["07:00-18:00"]
        peak_buffer_size_percent = 10
        off_peak_buffer_size_percent        = 0
        off_peak_disconnect_action          = "Shutdown"
        off_peak_extended_disconnect_action = "Shutdown"
        off_peak_log_off_action             = "Shutdown"
      }
    ]
  }

  depends_on = [citrix_machine_catalog.vid_w11]
}
