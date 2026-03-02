/*
    DESCRIPTION:
    Gemeinsame Build-Einstellungen für alle Packer Builds (alle Hypervisoren, alle OS-Versionen).
    Enthält VM-Verhalten, Content Library, OVF-Export und Timeout-Einstellungen.

    Update this file when:
      - Die vSphere VM Hardware Version aktualisiert wird (common_vm_version)
      - Timeouts für langsame Umgebungen angepasst werden müssen
      - common_template_conversion geändert werden soll (VM → Template oder umgekehrt)

    DO NOT put vSphere connection settings here  → packer/config/vsphere.pkrvars.hcl
    DO NOT put ISO or SMB settings here          → packer/config/sources.pkrvars.hcl
    DO NOT put build-user credentials here       → packer/config/build.pkrvars.hcl
    DO NOT put VM hardware settings here         → windows.auto.pkrvars.hcl
*/

// ─────────────────────────────────────────────────────────────────────────────
// Virtual Machine Settings
// common_vm_version: vSphere Virtual Hardware Version
//   19 = vSphere 7.0 U2+   20 = vSphere 8.0   21 = vSphere 8.0 U1+
// common_tools_upgrade_policy: VMware Tools beim ersten Boot nach Build aktualisieren
// common_remove_cdrom: ISO-Laufwerke nach Build entfernen (empfohlen: true)
// ─────────────────────────────────────────────────────────────────────────────

common_vm_version           = 19
common_tools_upgrade_policy = true
common_remove_cdrom         = true

// ─────────────────────────────────────────────────────────────────────────────
// Template / Export Settings
//
// AKTUELL: Citrix MCS zeigt direkt auf die Packer-Build-VM (kein Template, keine Content Library).
//   → common_template_conversion = false
//   → common_content_library_skip_export = true
//   Die VM verbleibt nach dem Build als normale VM in vsphere_folder.
//   MCS Master Image = diese VM direkt. Bei jedem Rebuild löscht Packer die alte VM
//   und erstellt eine neue mit demselben Namen.
//
// Alternative – VM Template (bei Bedarf aktivierbar):
//   → common_template_conversion = true
//   MCS unterstützt auch Templates als Master Image. Template kann nicht gestartet werden,
//   was eine versehentliche Modifikation verhindert.
//
// Content Library (normalerweise nicht nötig):
//   → common_template_conversion = false + common_content_library_name setzen
//   Sinnvoll nur wenn mehrere vCenter oder OVF-Portabilität benötigt wird.
//   Content Library muss vorab in vCenter manuell angelegt sein.
//   HINWEIS: VMs mit vTPM können nicht als OVF exportiert werden!
// ─────────────────────────────────────────────────────────────────────────────

common_template_conversion         = false   // false = VM bleibt als VM, MCS zeigt direkt darauf
common_content_library_skip_export = true    // kein Content Library Export (VM bleibt erhalten)

// Content Library aktivieren: common_content_library_skip_export = false setzen und folgende
// Zeilen einkommentieren (Content Library muss in vCenter vorab angelegt sein):
// common_content_library_name    = "VID-lib"
// common_content_library_ovf     = false
// common_content_library_destroy = true

// ─────────────────────────────────────────────────────────────────────────────
// OVF Export Settings (alternativ zur Content Library, normalerweise deaktiviert)
// ─────────────────────────────────────────────────────────────────────────────

common_ovf_export_enabled   = false
common_ovf_export_overwrite = true

// ─────────────────────────────────────────────────────────────────────────────
// ISO Datastore → packer/config/sources.pkrvars.hcl
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Boot and Provisioning Settings
// common_data_source: "http" = autounattend.xml via HTTP (Packer-Host muss erreichbar sein)
//                    "disk"  = autounattend.xml via virtuelles CD (kein HTTP nötig)
// common_http_ip: null = automatische Erkennung der Packer-Host-IP
//                IP   = explizite IP falls mehrere Netzwerkinterfaces vorhanden (z.B. WSL)
//
// HINWEIS für WSL/Linux: Falls die VM den Packer-Host nicht per HTTP erreichen kann,
// common_http_ip auf die IP des Linux/WSL-Hosts im vSphere-Netzwerk setzen.
// ─────────────────────────────────────────────────────────────────────────────

common_data_source      = "http"
common_http_ip          = null      // ← bei WSL: IP des Linux-Hosts eintragen (z.B. "192.168.1.10")
common_http_port_min    = 8000
common_http_port_max    = 8099
common_ip_wait_timeout  = "60m"     // Wartezeit bis VM eine IP bekommt (Windows-Install + VMware Tools ~45 Min)
common_shutdown_timeout = "15m"     // Wartezeit beim Herunterfahren nach Build

// ─────────────────────────────────────────────────────────────────────────────
// HCP Packer Registry (HashiCorp Cloud Platform – normalerweise deaktiviert)
// ─────────────────────────────────────────────────────────────────────────────

common_hcp_packer_registry_enabled = false
