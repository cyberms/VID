/*
    DESCRIPTION:
    Windows 11 VM-Hardware und OS-Metadaten.
    Diese Datei beschreibt WAS gebaut wird (Hardware-Specs, OS-Edition, Sprache).

    Update this file when:
      - Die Windows-Edition wechselt (Eval → Pro/Enterprise/Business)
      - Die VM-Hardware-Größe angepasst wird (CPU, RAM, Disk)
      - Die Sprach-/Tastatureinstellungen geändert werden

    ISO-Pfade + Checksummen          → packer/config/sources.pkrvars.hcl
    SMB VID-Data Repository          → packer/config/sources.pkrvars.hcl
    vSphere-Verbindung               → packer/config/vsphere.pkrvars.hcl
    Build-Account-Credentials        → packer/config/build.pkrvars.hcl
    Gemeinsame Build-Einstellungen   → packer/config/common.pkrvars.hcl
*/

// ─────────────────────────────────────────────────────────────────────────────
// Installation Operating System Metadata
// vm_inst_os_image: muss exakt dem Editionsnamen im WIM-Index der ISO entsprechen.
//   Eval-ISO:       "Windows 11 Enterprise Evaluation"
//   Business-ISO:   "Windows 11 Pro" / "Windows 11 Enterprise"
// vm_inst_os_kms_key: leer lassen für Eval-ISO. Für lizenzierte ISOs KMS-Key eintragen:
//   W11 Pro:        W269N-WFGWX-YVC9B-4J6C9-T83GX
//   W11 Enterprise: NPPR9-FWDCX-D2C8J-H872K-2YT43
// ─────────────────────────────────────────────────────────────────────────────

vm_inst_os_language = "en-US"
vm_inst_os_keyboard = "de-DE"
vm_inst_os_image    = "Windows 11 Enterprise Evaluation"
vm_inst_os_kms_key  = ""   // leer = kein Produktschlüssel (Eval-ISO)

// ─────────────────────────────────────────────────────────────────────────────
// Guest Operating System Metadata
// vm_guest_os_keyboard: Tastaturlayout innerhalb von Windows (de_DE = Deutsch)
// vm_guest_os_timezone: Windows-Zeitzonenname (Get-TimeZone -ListAvailable)
// vm_guest_os_edition:  Nur für VM-Benennung verwendet (kein Einfluss auf Installation)
// ─────────────────────────────────────────────────────────────────────────────

vm_guest_os_language = "en-US"
vm_guest_os_keyboard = "de_DE"
vm_guest_os_timezone = "W. Europe Standard Time"
vm_guest_os_family   = "windows"
vm_guest_os_name     = "desktop"
vm_guest_os_version  = "11"
vm_guest_os_edition  = "ent-eval"      // nur für VM-Name, nicht für Installation relevant

// Virtual Machine Guest OS Type (VMware guestId)
// windows9_64Guest = Windows 10/11 64-Bit
vm_guest_os_type = "windows9_64Guest"

// ─────────────────────────────────────────────────────────────────────────────
// Virtual Machine Hardware Settings
// vm_disk_size: in MB → 102400 = 100 GB
// vm_mem_size:  in MB → 4096 = 4 GB (Mindestempfehlung für W11 VDI: 4–8 GB)
// vm_vtpm:      true = vTPM 2.0 (Pflicht für W11, benötigt efi-secure Firmware)
// ─────────────────────────────────────────────────────────────────────────────

vm_firmware              = "efi-secure"   // Pflicht für Windows 11
vm_cdrom_type            = "sata"
vm_cpu_count             = 2
vm_cpu_cores             = 1
vm_cpu_hot_add           = false
vm_mem_size              = 4096
vm_mem_hot_add           = false
vm_vtpm                  = true
vm_disk_size             = 102400
vm_disk_controller_type  = ["pvscsi"]
vm_disk_thin_provisioned = true
vm_network_card          = "vmxnet3"
vm_video_mem_size        = 131072   // 128 MB VRAM (empfohlen für HDX/Blast)
vm_video_displays        = 1

// ─────────────────────────────────────────────────────────────────────────────
// Boot Settings
// vm_boot_wait: kurze Pause vor Boot-Befehl (verhindert verfrühte Eingabe)
// vm_shutdown_command: sauberes Herunterfahren nach Build-Abschluss
// ─────────────────────────────────────────────────────────────────────────────

vm_boot_order       = "disk,cdrom"
vm_boot_wait        = "3s"
vm_boot_command     = ["<spacebar><spacebar>"]
vm_shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Shutdown by Packer\""

// ─────────────────────────────────────────────────────────────────────────────
// Communicator Settings (WinRM)
// communicator_timeout: großzügig setzen – Windows Updates können lange dauern
// ─────────────────────────────────────────────────────────────────────────────

communicator_port    = 5985
communicator_timeout = "12h"

// ─────────────────────────────────────────────────────────────────────────────
// Provisioner Settings – Vendor Independence Day (VID) Layer-Zuordnung
// ─────────────────────────────────────────────────────────────────────────────

// [VID Layer 5 – W11 OS] Broker-agnostische OS-Baseline (läuft vor allen Vendor-Tools)
scripts_layer5 = [
  "scripts/windows/windows-prepare.ps1"
]

// [VID Layer 6 – Drivers]  VMware Tools: Einbindung via iso_paths (sources.pkrvars.hcl)
//                          Kein separates Skript nötig – autounattend.xml ruft windows-vmtools.ps1 auf
// [VID Layer 7a – Broker]  Citrix VDA: windows-citrix-vda.ps1 (windows.pkr.hcl Step 7)
// [VID Layer 7a+7b – Opt]  windows-citrix-optimize.ps1       (windows.pkr.hcl Step 10)
// [VID Layer 7 – Finalize] windows-citrix-mcs-prep.ps1       (windows.pkr.hcl Step 11)
// [VID Layer 8 – DEX]      windows-dex-agent.ps1             (später, noch deaktiviert)

// Inline-Befehl: Event Logs leeren am Ende der OS-Baseline-Phase (vor VDA)
inline = [
  "Get-EventLog -LogName * | ForEach { Clear-EventLog -LogName $_.Log }"
]
