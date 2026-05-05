/*
    DESCRIPTION:
    Microsoft Windows 11 – Multi-Broker VDI master image template
    using the Packer Builder for VMware vSphere (vsphere-iso).
    Unterstützte Broker: citrix-mcs, citrix-pvs, horizon, none

    Vendor Independence Day (VID) – Schicht-Klassifizierung:
      Schicht 5 – W11 OS Image    : Steps 1–6   (pure OS, hypervisor-agnostic)
      Schicht 6 – Drivers         : Step 2      (VMware Tools)
      Schicht 7 – Broker + Profile: Steps 7–13  (Agent, Optimize, Finalize)

    Build Pipeline:
      1. Windows 11 unattended installation (autounattend.xml)             [Schicht 5]
      2. VMware Tools installation (windows-vmtools.ps1)                   [Schicht 6]
      3. WinRM initialization (windows-init.ps1)                           [Schicht 5]
      4. Windows OS Baseline DSC (windows-dsc-apply.ps1)                   [Schicht 5]
      5. Windows Updates – pre-Agent                                       [Schicht 5]
      6a. Domain Join (windows-domain-join.ps1) – optional                 [Schicht 5→7]
      6b. Reboot after Domain Join                                         [Schicht 5→7]
      7a. Citrix VDA (windows-citrix-vda.ps1)          [vid_broker=citrix] [Schicht 7a]
      7b. Horizon Agent (windows-horizon-agent.ps1)    [vid_broker=horizon] [Schicht 7a]
      8.  Reboot nach Agent-Installation                                   [Schicht 7a]
      9.  Post-Agent Windows Updates                                       [Schicht 7a]
     10.  Application installation (windows-apps-install.ps1)              [Schicht 7c]
     11.  Generic VDI Optimize (windows-vdi-optimize.ps1)    [ALL broker]  [Schicht 7b]
     11a. Citrix-specific Optimize (windows-citrix-optimize.ps1) [citrix]  [Schicht 7b]
     11b. Horizon-specific Optimize (windows-horizon-optimize.ps1) [horiz] [Schicht 7b]
     12a. MCS/PVS Prep (windows-citrix-mcs-prep.ps1)         [citrix]      [Schicht 7]
     12b. IC-Prep (windows-horizon-ic-prep.ps1)               [horizon]     [Schicht 7]
     13.  Final event log clear + Temp cleanup                              [Finalize]

    MCS Note: Sysprep is NOT required for Citrix or Horizon.
    MCS/IC handles machine identity (SID, hostname) during provisioning.

    VID Principle: Schicht 5 (OS) + 7c (Apps) sind broker-agnostisch.
    Schicht 7a/7b: nur die Broker-Scripts austauschen – kein Eingriff in Schicht 5/6.
*/

//  BLOCK: packer
//  The Packer configuration.

packer {
  required_version = ">= 1.9.1"
  required_plugins {
    git = {
      version = ">= 0.4.2"
      source  = "github.com/ethanmdavidson/git"
    }
    vsphere = {
      version = ">= v1.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
    windows-update = {
      version = ">= 0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

//  BLOCK: data
//  Defines the data sources.

data "git-repository" "cwd" {}

//  BLOCK: locals
//  Defines the local variables.

locals {
  build_by           = "Built by: HashiCorp Packer ${packer.version}"
  build_date         = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version      = data.git-repository.cwd.head
  build_description  = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  // VMware Tools ISO path:
  //   - Custom datastore: "[datastore2] vmwaretools/windows.iso"
  //   - ESXi host-local:  "[] /vmimages/tools-isoimages/windows.iso"
  // Controlled via vmtools_iso_datastore + vmtools_iso_path in sources.pkrvars.hcl
  vmtools_iso_path_resolved = var.vmtools_iso_datastore != "" ? (
    "[${var.vmtools_iso_datastore}] ${var.vmtools_iso_path}"
  ) : (
    "[] ${var.vmtools_iso_path}"
  )
  // VDA installer ISO path (optional).
  // Set vid_vda_iso_datastore in sources.pkrvars.hcl to mount a pre-built VDA
  // ISO as a third CD-ROM. The windows-citrix-vda.ps1 CD-ROM fallback detects
  // it automatically. Leave empty to use the SMB share instead (Option A).
  vda_iso_path_resolved = var.vid_vda_iso_datastore != "" ? (
    "[${var.vid_vda_iso_datastore}] ${var.vid_vda_iso_path}"
  ) : ""
  iso_paths = concat(
    [
      "[${var.common_iso_datastore}] ${var.iso_path}/${var.iso_file}",
      local.vmtools_iso_path_resolved,
    ],
    // Only add the VDA ISO when vid_vda_iso_datastore is configured
    local.vda_iso_path_resolved != "" ? [local.vda_iso_path_resolved] : []
  )
  iso_checksum       = "${var.iso_checksum_type}:${var.iso_checksum_value}"
  manifest_date      = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path      = "${path.cwd}/manifests/"
  manifest_output    = "${local.manifest_path}${local.manifest_date}.json"
  ovf_export_path    = "${path.cwd}/artifacts/${local.vm_name}"
  vm_name            = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-${var.vm_guest_os_edition}-${local.build_version}"
  bucket_name        = replace("${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-${var.vm_guest_os_edition}", ".", "")
  bucket_description = "${var.vm_guest_os_family} ${var.vm_guest_os_name} ${var.vm_guest_os_version} ${var.vm_guest_os_edition}"
}

//  BLOCK: source
//  Defines the builder configuration blocks.

source "vsphere-iso" "windows-desktop" {

  // vCenter Server Endpoint Settings and Credentials
  vcenter_server      = var.vsphere_endpoint
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection

  // vSphere Settings
  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  datastore  = var.vsphere_datastore
  folder     = var.vsphere_folder

  // Virtual Machine Settings
  vm_name              = local.vm_name
  guest_os_type        = var.vm_guest_os_type
  firmware             = var.vm_firmware
  CPUs                 = var.vm_cpu_count
  cpu_cores            = var.vm_cpu_cores
  CPU_hot_plug         = var.vm_cpu_hot_add
  RAM                  = var.vm_mem_size
  RAM_hot_plug         = var.vm_mem_hot_add
  video_ram            = var.vm_video_mem_size
  displays             = var.vm_video_displays
  vTPM                 = var.vm_vtpm
  cdrom_type           = var.vm_cdrom_type
  disk_controller_type = var.vm_disk_controller_type
  storage {
    disk_size             = var.vm_disk_size
    disk_thin_provisioned = var.vm_disk_thin_provisioned
  }
  // D: data disk (10 GB) – present in the master image for build-time preparations.
  // Purpose: pagefile config, log folders and other D:\ preparations during the Packer build.
  // MCS BEHAVIOUR: MCS IODriver does NOT clone this disk to provisioned VMs.
  // Instead it attaches a fresh write-cache disk (also D:) to each new VM.
  // The pagefile registry setting (D:\pagefile.sys) set in mcs-prep.ps1 takes effect
  // on first boot of the provisioned VM once MCS has attached its D: write-cache disk.
  // NOTE: dynamic "storage" blocks are not supported by the vsphere-iso provider.
  // The disk is always present in the master template (all vid_broker values).
  // For non-MCS builds it remains raw/unformatted – windows-init-data-disk.ps1
  // only runs when vid_broker = "citrix-mcs" (dynamic provisioner block below).
  storage {
    disk_size             = var.vm_disk_d_size
    disk_thin_provisioned = var.vm_disk_thin_provisioned
  }
  network_adapters {
    network      = var.vsphere_network
    network_card = var.vm_network_card
  }
  vm_version           = var.common_vm_version
  remove_cdrom         = var.common_remove_cdrom
  tools_upgrade_policy = var.common_tools_upgrade_policy
  notes                = local.build_description

  // Removable Media Settings
  iso_paths    = local.iso_paths
  iso_checksum = local.iso_checksum
  cd_files = [
    "${path.cwd}/scripts/${var.vm_guest_os_family}/"
  ]
  cd_content = {
    "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
      build_username       = var.build_username
      build_password       = var.build_password
      vm_inst_os_language  = var.vm_inst_os_language
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_inst_os_image     = var.vm_inst_os_image
      vm_inst_os_kms_key   = var.vm_inst_os_kms_key
      vm_guest_os_language = var.vm_guest_os_language
      vm_guest_os_keyboard = var.vm_guest_os_keyboard
      vm_guest_os_timezone = var.vm_guest_os_timezone
    })
  }

  // Boot and Provisioning Settings
  http_port_min    = var.common_http_port_min
  http_port_max    = var.common_http_port_max
  boot_order       = var.vm_boot_order
  boot_wait        = var.vm_boot_wait
  boot_command     = var.vm_boot_command
  ip_wait_timeout  = var.common_ip_wait_timeout
  shutdown_command = var.vm_shutdown_command
  shutdown_timeout = var.common_shutdown_timeout

  // Communicator Settings and Credentials
  communicator   = "winrm"
  winrm_username = var.build_username
  winrm_password = var.build_password
  winrm_port     = var.communicator_port
  winrm_timeout  = var.communicator_timeout

  // Template and Content Library Settings
  convert_to_template = var.common_template_conversion
  # dynamic "content_library_destination" {
  #   for_each = var.common_content_library_name != null ? [1] : []
  #   content {
  #     library     = var.common_content_library_name
  #     description = local.build_description
  #     ovf         = false // Will transfer as a VM Template
  #     destroy     = var.common_content_library_destroy
  #     skip_import = var.common_content_library_skip_export
  #   }
  # }

  // OVF Export Settings
  dynamic "export" {
    for_each = var.common_ovf_export_enabled == true ? [1] : []
    content {
      name  = local.vm_name
      force = var.common_ovf_export_overwrite
      options = [
        "extraconfig"
      ]
      output_directory = local.ovf_export_path
    }
  }
}

//  BLOCK: build
//  Defines the builders to run, provisioners, and post-processors.

build {
  sources = [
    "source.vsphere-iso.windows-desktop",
  ]

  // Step 1–4 [VID Schicht 5 – W11 OS] + [Schicht 6 – Drivers]: OS Baseline scripts
  // windows-prepare.ps1: TLS hardening, Explorer settings, Passwort-Policy
  provisioner "powershell" {
    environment_vars = [
      "BUILD_USERNAME=${var.build_username}"
    ]
    elevated_user     = var.build_username
    elevated_password = var.build_password
    scripts           = formatlist("${path.cwd}/%s", length(var.scripts_layer5) > 0 ? var.scripts_layer5 : var.scripts)
  }

  // Step 2: Initial inline commands (e.g. clear event logs for clean baseline)
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    inline            = var.inline
  }

  // Step 2c [VID Schicht 7 – citrix-mcs only]: Initialise D: data disk
  // Runs only when vid_broker = "citrix-mcs" (static storage block always adds the disk;
  // dynamic "storage" is not supported by the vsphere-iso provider).
  // Partitions (GPT) and formats (NTFS) the disk so scripts can write to D:\ during build.
  // The pagefile is configured in windows-citrix-mcs-prep.ps1 (Step 12, step [9]).
  dynamic "provisioner" {
    for_each = var.vid_broker == "citrix-mcs" ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      scripts           = ["${path.cwd}/scripts/windows/windows-init-data-disk.ps1"]
    }
  }

  // Step 5 [VID Schicht 5 – W11 OS]: Windows Updates (pre-VDA) – OS-level patches only
  provisioner "windows-update" {
    pause_before    = "30s"
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*VMware*'",
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Defender*'",
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true"
    ]
    restart_timeout = "120m"
  }

  // ── LAYER 5→7 TRANSITION: Active Directory Domain Join ───────────────────────

  // Step 6a [VID Schicht 5→7]: Domain Join (optional, nur wenn domain_join_enabled = true)
  // Erfolgt NACH Windows Updates und VOR der Citrix VDA Installation, damit der
  // VDA sich beim Delivery Controller mit dem korrekten Domänen-FQDN registriert.
  // Credentials werden aus build.pkrvars.hcl gelesen (nicht im Repo).
  // OU-Pfad Beispiel: OU=GoldenImage,OU=VDI,OU=Clients,DC=sav-kb,DC=de
  dynamic "provisioner" {
    for_each = var.domain_join_enabled && !var.build_layer5_only ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = [
        "PKR_VAR_domain_name=${var.domain_name}",
        "PKR_VAR_domain_join_username=${var.domain_join_username}",
        "PKR_VAR_domain_join_password=${var.domain_join_password}",
        "PKR_VAR_domain_join_ou=${var.domain_join_ou}",
        "PKR_VAR_domain_join_computer_name=${var.domain_join_computer_name}",
      ]
      scripts = ["${path.cwd}/scripts/windows/windows-domain-join.ps1"]
    }
  }

  // Step 6b: Neustart nach Domain-Join
  dynamic "provisioner" {
    for_each = var.domain_join_enabled && !var.build_layer5_only ? [1] : []
    labels   = ["windows-restart"]
    content {
      restart_timeout       = "15m"
      restart_check_command = "powershell -command \"& {Write-Output 'Domain-Join Neustart abgeschlossen'}\""
    }
  }

  // ── BROKER AGENT STEPS (vid_broker steuert welcher Agent installiert wird) ────
  // VID Layer-Prinzip: Layer 5 (OS) + Layer 7c (Apps) sind broker-agnostisch.
  // Nur Layer 7a (Broker Agent) + 7b (Optimierungen) + 7 Finalize sind broker-spezifisch.
  //
  //   vid_broker = "citrix-mcs"  → Citrix VDA + MCS-Prep
  //   vid_broker = "citrix-pvs"  → Citrix VDA + PVS-Prep (pagefile ClearOnShutdown)
  //   vid_broker = "horizon"     → VMware/Broadcom Horizon Agent + IC-Prep
  //   vid_broker = "avd"         → eigenes Template: windows/desktop/11-avd/ (azure-arm)
  //   vid_broker = "none"        → kein Broker Agent (generic standalone image)
  //
  // Agent wird VOR den Apps installiert, damit er bereits domain-joined ist.

  // Step 7a [VID Schicht 7a – Citrix]: Citrix VDA Installation
  // Installer vom VID-Data SMB-Share: \\<server>\VID-Data\citrix\vda\<installer>
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && (var.vid_broker == "citrix-mcs" || var.vid_broker == "citrix-pvs") ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = [
        // Option A – SMB Share (primary, hypervisor-agnostic)
        "VID_SMB_SERVER=${var.vid_smb_server}",
        "VID_SMB_SHARE=${var.vid_smb_share}",
        "VID_SMB_USERNAME=${var.vid_smb_username}",
        "VID_SMB_PASSWORD=${var.vid_smb_password}",
        "VID_VDA_INSTALLER=${var.vid_vda_installer}",
        // Option B – vCenter Datastore Browser (uncomment to use as fallback):
        // "VCENTER_URL=https://${var.vsphere_endpoint}",
        // "VCENTER_USERNAME=${var.vsphere_username}",
        // "VCENTER_PASSWORD=${var.vsphere_password}",
        // "VSPHERE_DATACENTER=${var.vsphere_datacenter}",
        // "VID_DATASTORE=datastore2",
        // "VID_PATH=VID-Data",
        // -- Broker / Delivery Technology ------------------------------------
        "VID_BROKER=${var.vid_broker}",
        // -- VDA Installer Flags (see variables.pkr.hcl for descriptions) ----
        "VID_VDA_MASTERMCS=${var.vid_vda_mastermcs}",
        "VID_VDA_XENDESKTOP_CLOUD=${var.vid_vda_xendesktop_cloud}",
        "VID_VDA_ENABLE_HDX_PORTS=${var.vid_vda_enable_hdx_ports}",
        "VID_VDA_ENABLE_HDX_UDP_PORTS=${var.vid_vda_enable_hdx_udp_ports}",
        "VID_VDA_ENABLE_EDT=${var.vid_vda_enable_edt}",
        "VID_VDA_ENABLE_SS_PORTS=${var.vid_vda_enable_ss_ports}",
        "VID_VDA_DISABLE_CEIP=${var.vid_vda_disable_ceip}",
        "VID_VDA_ENABLE_REMOTE_ASSISTANCE=${var.vid_vda_enable_remote_assistance}",
        // -- VDA Components (names are case-sensitive per Citrix docs) --------
        "VID_VDA_INCLUDE_MACHINE_IDENTITY=${var.vid_vda_include_machine_identity}",
        "VID_VDA_INCLUDE_UPM=${var.vid_vda_include_upm}",
        "VID_VDA_INCLUDE_MCS_IO_DRIVER=${var.vid_vda_include_mcs_io_driver}",
        "VID_VDA_INCLUDE_RENDEZVOUS=${var.vid_vda_include_rendezvous}",
        "VID_VDA_INCLUDE_WEBSOCKET=${var.vid_vda_include_websocket}",
        "VID_VDA_INCLUDE_UPGRADE_AGENT=${var.vid_vda_include_upgrade_agent}",
        "VID_VDA_INCLUDE_UPL=${var.vid_vda_include_upl}",
      ]
      scripts           = ["${path.cwd}/scripts/windows/windows-citrix-vda.ps1"]
      // Without /noreboot the installer may reboot the VM mid-script.
      // Exit codes 8, 1641, 3010 = success + reboot required.
      // Exit code 1 may occur when the VM reboots and kills the WinRM session.
      valid_exit_codes  = [0, 1, 3, 8, 1641, 3010]
    }
  }

  // Step 7b [VID Schicht 7a – Horizon]: VMware/Broadcom Horizon Agent Installation
  // Installer vom VID-Data SMB-Share: \\<server>\VID-Data\vmware\horizon\<installer>
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && var.vid_broker == "horizon" ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = [
        "VID_SMB_SERVER=${var.vid_smb_server}",
        "VID_SMB_SHARE=${var.vid_smb_share}",
        "VID_SMB_USERNAME=${var.vid_smb_username}",
        "VID_SMB_PASSWORD=${var.vid_smb_password}",
        "VID_BROKER=${var.vid_broker}",
        "VID_HORIZON_INSTALLER=${var.vid_horizon_installer}",
      ]
      scripts          = ["${path.cwd}/scripts/windows/windows-horizon-agent.ps1"]
      valid_exit_codes = [0, 1, 3010, 3011]
    }
  }

  // Step 8 [VID Schicht 7a]: Reboot to complete Agent installation (Citrix + Horizon)
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && (var.vid_broker == "citrix-mcs" || var.vid_broker == "citrix-pvs" || var.vid_broker == "horizon") ? [1] : []
    labels   = ["windows-restart"]
    content {
      restart_timeout       = "30m"
      restart_check_command = "powershell -command \"& {Write-Output 'Restart completed'}\""
    }
  }

  // Step 9 [VID Schicht 7a]: Post-Agent Windows Updates (Citrix + Horizon)
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && (var.vid_broker == "citrix-mcs" || var.vid_broker == "citrix-pvs" || var.vid_broker == "horizon") ? [1] : []
    labels   = ["windows-update"]
    content {
      pause_before    = "30s"
      search_criteria = "IsInstalled=0"
      filters = [
        "exclude:$_.Title -like '*VMware*'",
        "exclude:$_.Title -like '*Preview*'",
        "exclude:$_.Title -like '*Defender*'",
        "exclude:$_.InstallationBehavior.CanRequestUserInput",
        "include:$true"
      ]
      restart_timeout = "120m"
    }
  }

  // ── LAYER 7 STEPS (übersprungen wenn build_layer5_only = true) ──────────────

  // Step 10a [VID Schicht 7c – Apps]: apps-manifest.json auf VM hochladen
  // Muss vor windows-apps-install.ps1 laufen, da das Script die Datei erwartet.
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
    labels   = ["file"]
    content {
      source      = "${path.cwd}/scripts/windows/apps-manifest.json"
      destination = "C:/Windows/Temp/apps-manifest.json"
    }
  }

  // Step 10b [VID Schicht 7c – Apps]: Applikationsinstallation
  // Wird in w11-full UND w11-vda ausgeführt – unabhängig von Citrix.
  // Apps werden aus apps-manifest.json gelesen (SMB oder lokaler Pfad).
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = [
        "VID_SMB_SERVER=${var.vid_smb_server}",
        "VID_SMB_SHARE=${var.vid_smb_share}",
        "VID_SMB_USERNAME=${var.vid_smb_username}",
        "VID_SMB_PASSWORD=${var.vid_smb_password}",
      ]
      scripts = ["${path.cwd}/scripts/windows/windows-apps-install.ps1"]
    }
  }

  // Step 10c [VID Schicht 8 – DEX/Monitoring]: DEAKTIVIERT – kommt am Ende des Projekts
  // Skript vorhanden: scripts/windows/windows-dex-agent.ps1
  // Provisioner hier einkommentieren wenn DEX-Phase startet.

  // Step 11 [VID Schicht 7b – ALL Broker]: Generische VDI Optimierungen (broker-agnostisch)
  // Läuft für ALLE Broker außer "none" und build_layer5_only.
  // Enthält: Power Plan, Services, Scheduled Tasks, Telemetrie, OneDrive,
  //          Netzwerk, Storage, AppX, Visual/UI, Event Logs, Terminal Services, ...
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && var.vid_broker != "none" ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = ["VID_BROKER=${var.vid_broker}"]
      scripts           = ["${path.cwd}/scripts/windows/windows-vdi-optimize.ps1"]
    }
  }

  // Step 11a [VID Schicht 7b – Citrix]: Citrix-spezifische Optimierungen
  // Läuft NUR für Citrix (nach dem generischen Optimize-Script).
  // Enthält: Defender Exclusions für Citrix-Verzeichnisse, CtxHook, EDT/UDT, HDX-Tweaks
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && (var.vid_broker == "citrix-mcs" || var.vid_broker == "citrix-pvs") ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = ["VID_BROKER=${var.vid_broker}"]
      scripts           = ["${path.cwd}/scripts/windows/windows-citrix-optimize.ps1"]
    }
  }

  // Step 11b [VID Schicht 7b – Horizon]: Horizon-spezifische Optimierungen
  // Läuft NUR für Horizon (nach dem generischen Optimize-Script).
  // Enthält: Blast Extreme Tweaks, OSOT-Referenz, Desktop Cleanup
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && var.vid_broker == "horizon" ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = ["VID_BROKER=${var.vid_broker}"]
      scripts           = ["${path.cwd}/scripts/windows/windows-horizon-optimize.ps1"]
    }
  }

  // Step 12a [VID Schicht 7 – Citrix Finalize]: MCS/PVS Master Image Preparation
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && (var.vid_broker == "citrix-mcs" || var.vid_broker == "citrix-pvs") ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = ["VID_BROKER=${var.vid_broker}"]
      scripts           = ["${path.cwd}/scripts/windows/windows-citrix-mcs-prep.ps1"]
    }
  }

  // Step 12b [VID Schicht 7 – Horizon Finalize]: Instant Clone Master Image Preparation
  dynamic "provisioner" {
    for_each = !var.build_layer5_only && var.vid_broker == "horizon" ? [1] : []
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      environment_vars  = ["VID_BROKER=${var.vid_broker}"]
      scripts           = ["${path.cwd}/scripts/windows/windows-horizon-ic-prep.ps1"]
    }
  }

  // Step 13 [VID – Finalize]: Final event log clear (immer, außer Schicht5-only)
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      inline            = [
        "Write-Output 'Performing final cleanup before template export...'",
        "Get-EventLog -LogName * | ForEach { Clear-EventLog -LogName $_.Log }",
        "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
        "Write-Output 'Final cleanup complete. Image ready for MCS.'"
      ]
    }
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_username           = var.build_username
      build_date               = local.build_date
      build_version            = local.build_version
      common_data_source       = var.common_data_source
      common_vm_version        = var.common_vm_version
      vm_cpu_cores             = var.vm_cpu_cores
      vm_cpu_count             = var.vm_cpu_count
      vm_disk_size             = var.vm_disk_size
      vm_disk_thin_provisioned = var.vm_disk_thin_provisioned
      vm_firmware              = var.vm_firmware
      vm_guest_os_type         = var.vm_guest_os_type
      vm_mem_size              = var.vm_mem_size
      vm_network_card          = var.vm_network_card
      vm_video_memory          = var.vm_video_mem_size
      vm_video_displays        = var.vm_video_displays
      vm_vtpm                  = var.vm_vtpm
      vsphere_cluster          = var.vsphere_cluster
      vsphere_datacenter       = var.vsphere_datacenter
      vsphere_datastore        = var.vsphere_datastore
      vsphere_endpoint         = var.vsphere_endpoint
      vsphere_folder           = var.vsphere_folder
    }
  }

  dynamic "hcp_packer_registry" {
    for_each = var.common_hcp_packer_registry_enabled ? [1] : []
    content {
      bucket_name = local.bucket_name
      description = local.bucket_description
      bucket_labels = {
        "os_family" : var.vm_guest_os_family,
        "os_name" : var.vm_guest_os_name,
        "os_version" : var.vm_guest_os_version,
        "os_edition" : var.vm_guest_os_edition,
      }
      build_labels = {
        "build_version" : local.build_version,
        "packer_version" : packer.version,
      }
    }
  }
}
