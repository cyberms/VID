/*
    DESCRIPTION:
    Vendor Independence Day (VID) - Layer 5 + 6
    Windows 11 Professional + Citrix VDA master image for Citrix Hypervisor (XenServer).
    
    Uses the xenserver-iso community Packer plugin.
    
    Build Pipeline:
      1. Windows 11 unattended installation
      2. Citrix VM Tools installation (windows-xenserver-tools.ps1) - Layer 6
      3. WinRM initialization
      4. OS baseline hardening (windows-prepare.ps1)
      5. Windows Updates
      6. Citrix VDA silent installation (windows-citrix-vda.ps1)
      7. Reboot
      8. Post-VDA Windows Updates
      9. VDI Optimizations (windows-citrix-optimize.ps1)
     10. MCS preparation (windows-citrix-mcs-prep.ps1)
*/

packer {
  required_version = ">= 1.9.1"
  required_plugins {
    xenserver = {
      version = ">= 0.7.0"
      source  = "github.com/xenserver/xenserver"
    }
    windows-update = {
      version = ">= 0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

locals {
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_description = "VID W11+VDA XenServer - Built: ${local.build_date}"
  vm_name           = "vid-${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-xenserver"
}

source "xenserver-iso" "windows-desktop" {
  // XenServer Connection
  remote_host     = var.xenserver_host
  remote_username = var.xenserver_username
  remote_password = var.xenserver_password

  // VM Settings
  vm_name         = local.vm_name
  vm_description  = local.build_description
  vm_memory       = var.vm_mem_size
  vcpus           = var.vm_cpu_count
  disk_size       = var.vm_disk_size

  // Guest OS
  sr_iso_name     = var.xenserver_sr_iso
  sr_name         = var.xenserver_sr

  // ISO
  iso_url         = ""
  iso_name        = var.iso_file
  iso_sr          = var.xenserver_sr_iso

  // Network
  network_names   = [var.xenserver_network]

  // Boot
  boot_wait       = var.vm_boot_wait
  boot_command    = ["<spacebar><spacebar>"]

  // Communicator (WinRM)
  communicator    = "winrm"
  winrm_username  = var.build_username
  winrm_password  = var.build_password
  winrm_port      = 5985
  winrm_timeout   = "12h"

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Shutdown by Packer - VID W11 XenServer\""
  shutdown_timeout = "15m"

  // Export as XVA template
  output_directory = "${path.cwd}/artifacts/xenserver/"
  keep_vm          = "always"
}

build {
  sources = ["source.xenserver-iso.windows-desktop"]

  // Step 1: OS Baseline
  provisioner "powershell" {
    environment_vars  = ["BUILD_USERNAME=${var.build_username}"]
    elevated_user     = var.build_username
    elevated_password = var.build_password
    scripts           = formatlist("${path.cwd}/%s", var.scripts)
  }

  // Step 2: Inline cleanup
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    inline            = var.inline
  }

  // Step 3: Windows Updates (pre-VDA)
  provisioner "windows-update" {
    pause_before    = "30s"
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true"
    ]
    restart_timeout = "120m"
  }

  // Step 4: Citrix VDA Installation (Layer 5-to-6 bridge)
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    scripts           = ["${path.cwd}/scripts/windows/windows-citrix-vda.ps1"]
  }

  // Step 5: Reboot post-VDA
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  // Step 6: Post-VDA Updates
  provisioner "windows-update" {
    pause_before    = "30s"
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true"
    ]
    restart_timeout = "120m"
  }

  // Step 7: VDI Optimizations
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    scripts           = ["${path.cwd}/scripts/windows/windows-citrix-optimize.ps1"]
  }

  // Step 8: MCS Prep
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    scripts           = ["${path.cwd}/scripts/windows/windows-citrix-mcs-prep.ps1"]
  }

  // Step 9: Final cleanup
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    inline = [
      "Get-EventLog -LogName * | ForEach { Clear-EventLog -LogName $_.Log }",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Write-Output 'VID XenServer W11 image ready for MCS.'"
    ]
  }

  post-processor "manifest" {
    output     = "${path.cwd}/manifests/${formatdate("YYYY-MM-DD hh:mm:ss", timestamp())}-xenserver.json"
    strip_path = true
    strip_time = true
  }
}
