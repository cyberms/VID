# ─────────────────────────────────────────────────────────────────────────────
# VID – AVD, Modul 1: Azure Infrastruktur
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Erstellt:
#   - Resource Group für AVD-Workload
#   - Virtual Network + Subnets
#   - Network Security Group (AVD-Grundregeln)
#   - RBAC: Desktop Virtualization User Role für AVD-Nutzergruppe
# ─────────────────────────────────────────────────────────────────────────────

locals {
  name_suffix = "${var.prefix}-avd-${var.environment}-${var.location_short}"
}

# ── Resource Group ────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "avd" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = var.tags
}

# ── Virtual Network ───────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "avd" {
  name                = "vnet-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  address_space       = [var.vnet_address_space]
  dns_servers         = length(var.dns_servers) > 0 ? var.dns_servers : null
  tags                = var.tags
}

resource "azurerm_subnet" "sessionhosts" {
  name                 = "snet-avd-sessionhosts"
  resource_group_name  = azurerm_resource_group.avd.name
  virtual_network_name = azurerm_virtual_network.avd.name
  address_prefixes     = [var.subnet_sessionhosts_cidr]
}

resource "azurerm_subnet" "mgmt" {
  name                 = "snet-avd-mgmt"
  resource_group_name  = azurerm_resource_group.avd.name
  virtual_network_name = azurerm_virtual_network.avd.name
  address_prefixes     = [var.subnet_mgmt_cidr]
}

# ── Network Security Group ────────────────────────────────────────────────────
resource "azurerm_network_security_group" "avd_sessionhosts" {
  name                = "nsg-${local.name_suffix}-sessionhosts"
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  tags                = var.tags

  # RDP direkt von außen blocken (Zugang nur über AVD Gateway)
  security_rule {
    name                       = "DenyRDPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # AVD Service Tags erlauben
  security_rule {
    name                       = "AllowAVDServiceTag"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "8443"]
    source_address_prefix      = "WindowsVirtualDesktop"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "sessionhosts" {
  subnet_id                 = azurerm_subnet.sessionhosts.id
  network_security_group_id = azurerm_network_security_group.avd_sessionhosts.id
}
