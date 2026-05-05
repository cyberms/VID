/*
    DESCRIPTION:
    Microsoft Windows 11 Single-Session + AVD Agent Master Image Template
    using the Packer Builder für Microsoft Azure (azure-arm).

    Vendor Independence Day (VID) – Schicht-Klassifizierung:
      Schicht 5 – W11 OS Image    : Steps 1–5   (pure OS, broker-agnostic)
      Schicht 6 – Drivers         : n/a          (Azure verwaltet Treiber über VHD)
      Schicht 7 – Broker + Apps   : Steps 6–10  (AVD Agent, FSLogix, Apps)

    Build Pipeline:
      1. Windows 11 Marketplace Image (autounattend über azure-arm CustomData)   [Schicht 5]
      2. WinRM initialization (windows-init.ps1)                                 [Schicht 5]
      3. Windows OS Baseline DSC (windows-dsc-apply.ps1)                         [Schicht 5]
      4. Windows Updates – pre-Agent                                              [Schicht 5]
      5. Domain Join (optional)                                                   [Schicht 5→7]
      6. AVD RD Agent + BootLoader (windows-avd-agent.ps1)                       [Schicht 7a]
      7. Reboot                                                                   [Schicht 7a]
      8. FSLogix (windows-avd-fslogix.ps1)                                       [Schicht 7b]
      9. Application installation (windows-apps-install.ps1)                     [Schicht 7c]
     10. Publish to Azure Compute Gallery (Shared Image Gallery)                 [Finalize]

    MCS Note: AVD nutzt KEINE MCS. Azure verwaltet VM-Identität beim Rollout.
    Registration Token wird beim VM-Deployment übergeben (Custom Script Extension
    oder Azure Policy) – NICHT im Image gespeichert.

    VID Principle: Schicht 5 (pure W11 OS) ist broker-agnostisch.
    Schicht 7 (AVD Agent + FSLogix): nur diese Scripts müssen gegenüber Citrix
    ausgetauscht werden – Schicht 5 und Apps sind identisch.

    Status: SKELETON – azure-arm Variablen (Subscription, Resource Group,
    Gallery etc.) müssen in variables.pkr.hcl und build.pkrvars.hcl ergänzt werden.
*/

//  BLOCK: packer
packer {
  required_version = ">= 1.9.1"
  required_plugins {
    azure = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/azure"
    }
    windows-update = {
      version = ">= 0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

//  BLOCK: locals
locals {
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  vm_name           = "${var.vm_guest_os_name}-avd-${formatdate("YYYYMMDD", timestamp())}"
  image_description = "VID AVD Golden Image – Built: ${local.build_date}"
}

//  BLOCK: source – Azure ARM Builder
source "azure-arm" "windows-avd" {
  // ── Azure Authentication ──────────────────────────────────────────────────
  // Empfohlen: Service Principal mit minimalen Rechten auf Resource Group + Gallery
  // Alternativ: Managed Identity auf dem Build-Server (kein client_secret nötig)
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id

  // ── Source Image ───────────────────────────────────────────────────────────
  // Windows 11 23H2 Multi-Session oder Single-Session vom Azure Marketplace
  // Single-Session für VID (Multi-Session kommt später)
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "windows-11"
  image_sku       = "win11-23h2-ent"    // Enterprise Single-Session
  image_version   = "latest"

  // ── Build VM ───────────────────────────────────────────────────────────────
  location                          = var.azure_location
  vm_size                           = var.azure_vm_size            // z.B. "Standard_D4s_v5"
  resource_group_name               = var.azure_build_resource_group
  storage_account                   = var.azure_build_storage_account
  temp_resource_group_name          = var.azure_temp_resource_group  // wird nach Build gelöscht

  // ── OS Disk ────────────────────────────────────────────────────────────────
  os_type         = "Windows"
  os_disk_size_gb = var.vm_disk_size_gb                            // z.B. 128

  // ── WinRM (Packer Communicator) ────────────────────────────────────────────
  // azure-arm konfiguriert WinRM automatisch über den CustomData/AutoLogon-Mechanismus
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "10m"
  winrm_username = var.build_username
  winrm_password = var.build_password

  // ── Azure Compute Gallery (Shared Image Gallery) ───────────────────────────
  // Ersetzt vSphere Content Library als Image-Distribution-Mechanismus
  shared_image_gallery_destination {
    subscription        = var.azure_subscription_id
    resource_group      = var.azure_gallery_resource_group
    gallery_name        = var.azure_gallery_name
    image_name          = var.azure_gallery_image_name            // z.B. "VID-W11-AVD"
    image_version       = formatdate("YYYY.MM.DD", timestamp())   // semver-ähnlich
    replication_regions = var.azure_gallery_replication_regions   // ["westeurope", "northeurope"]
  }

  // ── Tags ───────────────────────────────────────────────────────────────────
  azure_tags = {
    Project     = "VID"
    Layer       = "7a"
    Broker      = "avd"
    BuildDate   = local.build_date
    ManagedBy   = "Packer"
  }
}

//  BLOCK: build
build {
  sources = [
    "source.azure-arm.windows-avd",
  ]

  // Step 1 [VID Schicht 5]: WinRM init (azure-arm benötigt eigene init-Sequenz)
  provisioner "powershell" {
    environment_vars = ["BUILD_USERNAME=${var.build_username}"]
    scripts          = ["${path.cwd}/../../scripts/windows/windows-init.ps1"]
  }

  // Step 2 [VID Schicht 5 – DSC]: OS Baseline (identisch mit vSphere-Template)
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    environment_vars  = ["BUILD_USERNAME=${var.build_username}"]
    scripts           = ["${path.cwd}/../../scripts/windows/windows-dsc-apply.ps1"]
  }

  // Step 3 [VID Schicht 5]: Windows Updates (pre-Agent)
  provisioner "windows-update" {
    pause_before    = "30s"
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Defender*'",
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true"
    ]
    restart_timeout = "120m"
  }

  // Step 4 [VID Schicht 7a – AVD]: RD Agent + BootLoader Installation
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    environment_vars  = [
      "VID_BROKER=avd",
      // Option A: SMB-Share (wenn kein Internet-Zugang)
      // "VID_SMB_SERVER=${var.vid_smb_server}",
      // "VID_SMB_SHARE=${var.vid_smb_share}",
      // "VID_SMB_USERNAME=${var.vid_smb_username}",
      // "VID_SMB_PASSWORD=${var.vid_smb_password}",
    ]
    scripts = ["${path.cwd}/../../scripts/windows/windows-avd-agent.ps1"]
    valid_exit_codes = [0, 3010]
  }

  // Step 5: Neustart nach AVD Agent
  provisioner "windows-restart" {
    restart_timeout       = "30m"
    restart_check_command = "powershell -command \"& {Write-Output 'Restart completed'}\""
  }

  // Step 6 [VID Schicht 7b – AVD]: FSLogix Profil-Container
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    scripts = ["${path.cwd}/../../scripts/windows/windows-avd-fslogix.ps1"]
    valid_exit_codes = [0, 3010]
  }

  // Step 7a [VID Schicht 7c – Apps]: apps-manifest.json hochladen
  provisioner "file" {
    source      = "${path.cwd}/../../scripts/windows/apps-manifest.json"
    destination = "C:/Windows/Temp/apps-manifest.json"
  }

  // Step 7b [VID Schicht 7c – Apps]: Applikationsinstallation (broker-agnostisch)
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    environment_vars  = [
      // Bei Azure-native: Apps via Winget (Internet-Zugang vorhanden)
      // SMB-Share optional für PSADT-Pakete mit großen Installern
      "VID_SMB_SERVER=${var.vid_smb_server}",
      "VID_SMB_SHARE=${var.vid_smb_share}",
      "VID_SMB_USERNAME=${var.vid_smb_username}",
      "VID_SMB_PASSWORD=${var.vid_smb_password}",
    ]
    scripts = ["${path.cwd}/../../scripts/windows/windows-apps-install.ps1"]
  }

  // Step 8 [Finalize]: Event-Logs leeren, Temp bereinigen
  provisioner "powershell" {
    elevated_user     = var.build_username
    elevated_password = var.build_password
    inline = [
      "Write-Output 'Final cleanup für Azure Compute Gallery Export...'",
      "Get-EventLog -LogName * | ForEach { Clear-EventLog -LogName $_.Log }",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      // Sysprep wird von azure-arm automatisch am Ende ausgeführt (wenn capture_container_name gesetzt)
      // Für Shared Image Gallery: azure-arm führt Sysprep/generalization via Azure API durch
      "Write-Output 'Cleanup abgeschlossen. Azure generalisiert das Image automatisch.'"
    ]
  }

  post-processor "manifest" {
    output     = "${path.cwd}/output/manifest-avd.json"
    strip_path = true
    strip_time = true
    custom_data = {
      broker      = "avd"
      build_date  = local.build_date
      gallery     = var.azure_gallery_name
      image_name  = var.azure_gallery_image_name
    }
  }
}
