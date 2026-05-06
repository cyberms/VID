# ─────────────────────────────────────────────────────────────────────────────
# VID – AVD, Modul 3: Session Hosts
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Erstellt:
#   - Network Interfaces
#   - Windows VMs (aus VID Packer-Image)
#   - Domain Join Extension (Hybrid oder AAD Join)
#   - AVD Agent + Bootloader via azurerm_virtual_machine_extension
# ─────────────────────────────────────────────────────────────────────────────

locals {
  use_gallery = var.image_source == "gallery"
}

# ── Image-Referenz (Compute Gallery oder Managed Image) ───────────────────────
data "azurerm_shared_image_version" "vid_image" {
  count               = local.use_gallery ? 1 : 0
  name                = var.gallery_image_version == "latest" ? "latest" : var.gallery_image_version
  image_name          = var.gallery_image_name
  gallery_name        = var.gallery_name
  resource_group_name = var.gallery_resource_group
}

# ── Network Interfaces ────────────────────────────────────────────────────────
resource "azurerm_network_interface" "sessionhost" {
  count               = var.vm_count
  name                = "nic-${var.vm_name_prefix}-${format("%03d", count.index + 1)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# ── Session Host VMs ──────────────────────────────────────────────────────────
resource "azurerm_windows_virtual_machine" "sessionhost" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${format("%03d", count.index + 1)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.sessionhost[count.index].id]

  os_disk {
    name                 = "osdisk-${var.vm_name_prefix}-${format("%03d", count.index + 1)}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # VID Packer-Image aus Azure Compute Gallery
  dynamic "source_image_id" {
    for_each = local.use_gallery ? [1] : []
    content {}
  }

  source_image_id = local.use_gallery ? (
    var.gallery_image_version == "latest"
      ? data.azurerm_shared_image_version.vid_image[0].id
      : data.azurerm_shared_image_version.vid_image[0].id
  ) : var.managed_image_id

  identity {
    type = var.domain_join_type == "aadj" ? "SystemAssigned" : "None"
  }

  lifecycle {
    ignore_changes = [source_image_id]
  }
}

# ── Domain Join Extension (Hybrid AD) ────────────────────────────────────────
resource "azurerm_virtual_machine_extension" "domain_join" {
  count                = var.domain_join_type == "hybrid" ? var.vm_count : 0
  name                 = "DomainJoin"
  virtual_machine_id   = azurerm_windows_virtual_machine.sessionhost[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = var.domain_fqdn
    OUPath  = var.domain_ou_path
    User    = "${var.domain_fqdn}\\${var.domain_join_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = var.domain_join_password
  })

  depends_on = [azurerm_windows_virtual_machine.sessionhost]
}

# ── AVD Agent + Bootloader ────────────────────────────────────────────────────
resource "azurerm_virtual_machine_extension" "avd_agent" {
  count                = var.vm_count
  name                 = "AVDAgent"
  virtual_machine_id   = azurerm_windows_virtual_machine.sessionhost[count.index].id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.73"

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.348.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName          = var.hostpool_name
      registrationInfoToken = var.registration_token
      aadJoin               = var.domain_join_type == "aadj"
    }
  })

  depends_on = [
    azurerm_virtual_machine_extension.domain_join,
    azurerm_windows_virtual_machine.sessionhost,
  ]
}
