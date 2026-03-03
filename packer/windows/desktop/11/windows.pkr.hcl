/*
    DESCRIPTION:
    Microsoft Windows 11 Professional + Citrix VDA master image template
    using the Packer Builder for VMware vSphere (vsphere-iso).

    Vendor Independence Day (VID) – Layer Classification:
      Layer 5 – W11 OS Image    : Steps 1–6  (pure OS, hypervisor-agnostic)
      Layer 6 – Drivers         : Step 2     (VMware Tools)
      Layer 7 – Broker + Profile: Steps 7–10 (Citrix VDA, optimizations, MCS prep)

    Build Pipeline:
      1. Windows 11 unattended installation (autounattend.xml)    [Layer 5]
      2. VMware Tools installation (windows-vmtools.ps1)          [Layer 6]
      3. WinRM initialization (windows-init.ps1)                  [Layer 5]
      4. Windows OS baseline hardening (windows-prepare.ps1)      [Layer 5]
      5. Windows Updates – pre-VDA                                [Layer 5]
      6. Reboot                                                   [Layer 5]
      7. Citrix VDA silent installation (windows-citrix-vda.ps1)  [Layer 7a – Broker Agent]
      8. Reboot to complete VDA installation                      [Layer 7a]
      9. Post-VDA Windows Updates                                 [Layer 7a]
     10. VDI optimizations (windows-citrix-optimize.ps1)          [Layer 7a+7b]
     11. MCS master image cleanup (windows-citrix-mcs-prep.ps1)   [Layer 7]
     12. Template / Content Library export for Citrix MCS

    MCS Note: Sysprep is NOT required. MCS handles machine identity (SID,
    hostname, domain join) automatically during provisioning.

    VID Principle: Layer 5 (pure W11 OS) is broker-agnostic.
    Layer 7 (VDA + Profile Management) is swappable without OS rebuild.
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
  iso_paths = [
    "[${var.common_iso_datastore}] ${var.iso_path}/${var.iso_file}",
    local.vmtools_iso_path_resolved
    // Citrix VDA is NOT mounted as ISO – installer is pulled from SMB at build time.
    // See: scripts/windows/windows-citrix-vda.ps1 – Option A (SMB)
  ]
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

  // Step 1–4 [VID Layer 5 – W11 OS] + [Layer 6 – Drivers]: OS Baseline scripts
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

  // Step 5 [VID Layer 5 – W11 OS]: Windows Updates (pre-VDA) – OS-level patches only
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

  // Step 6a [VID Layer 5→7]: Domain Join (optional, nur wenn domain_join_enabled = true)
  // Erfolgt NACH Windows Updates und VOR der Citrix VDA Installation.
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

  // ── LAYER 7 STEPS (übersprungen wenn build_layer5_only = true) ──────────────

  // Step 7 [VID Layer 7a – Broker Agent]: Citrix VDA Installation
  // The VDA installer is pulled from the VID-Data SMB share at build time:
  //   \\<vid_smb_server>\VID-Data\citrix\vda\<vid_vda_installer>
  // Credentials are passed as environment variables; no domain join required.
  // SWAP THIS STEP to replace Citrix with AVD Agent, Horizon Agent, etc.
  //
  // Fallback: if SMB env vars are not set, the script tries the vCenter
  // Datastore Browser API (Option B), then CD-ROM detection.
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
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
      ]
      scripts           = ["${path.cwd}/scripts/windows/windows-citrix-vda.ps1"]
    }
  }

  // Step 8 [VID Layer 7a]: Reboot to complete VDA installation
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
    labels   = ["windows-restart"]
    content {
      restart_timeout       = "30m"
      restart_check_command = "powershell -command \"& {Write-Output 'Restart completed'}\""
    }
  }

  // Step 9 [VID Layer 7a]: Post-VDA Windows Updates
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
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

  // Step 10 [VID Layer 7a+7b – Broker + Profile]: VDI Optimizations
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      scripts           = ["${path.cwd}/scripts/windows/windows-citrix-optimize.ps1"]
    }
  }

  // Step 10b [VID Layer 8 – DEX/Monitoring]: für spätere Phase vorgesehen
  // Skript: scripts/windows/windows-dex-agent.ps1 (ControlUp / uberagent)

  // Step 11 [VID Layer 7 – Finalize]: MCS Master Image Preparation (cleanup, no sysprep!)
  dynamic "provisioner" {
    for_each = var.build_layer5_only ? [] : [1]
    labels   = ["powershell"]
    content {
      elevated_user     = var.build_username
      elevated_password = var.build_password
      scripts           = ["${path.cwd}/scripts/windows/windows-citrix-mcs-prep.ps1"]
    }
  }

  // Step 12 [VID Layer 7 – Finalize]: Final event log clear before template export
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
