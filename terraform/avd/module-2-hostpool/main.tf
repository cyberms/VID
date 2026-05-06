# ─────────────────────────────────────────────────────────────────────────────
# VID – AVD, Modul 2: Host Pool, Workspace, Application Groups
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Erstellt:
#   - azurerm_virtual_desktop_host_pool
#   - azurerm_virtual_desktop_host_pool_registration_info (Token für Session Hosts)
#   - azurerm_virtual_desktop_workspace
#   - azurerm_virtual_desktop_application_group (Desktop + optional RemoteApp)
#   - azurerm_virtual_desktop_workspace_application_group_association
#   - azurerm_role_assignment: Desktop Virtualization User für AVD-Nutzergruppe
# ─────────────────────────────────────────────────────────────────────────────

# ── Host Pool ─────────────────────────────────────────────────────────────────
resource "azurerm_virtual_desktop_host_pool" "main" {
  name                     = var.hostpool_name
  friendly_name            = var.hostpool_friendly_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  type                     = var.hostpool_type
  load_balancer_type       = var.hostpool_load_balancer_type
  maximum_sessions_allowed = var.hostpool_max_sessions_per_host
  start_vm_on_connect      = var.hostpool_start_vm_on_connect
  validate_environment     = false

  tags = var.tags
}

# Registrierungstoken (gültig 2h – wird in Modul 3 für Session Host Join verwendet)
resource "time_rotating" "avd_token" {
  rotation_hours = 2
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "main" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.main.id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

# ── Workspace ─────────────────────────────────────────────────────────────────
resource "azurerm_virtual_desktop_workspace" "main" {
  name                = var.workspace_name
  friendly_name       = var.workspace_friendly_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# ── Desktop Application Group ─────────────────────────────────────────────────
resource "azurerm_virtual_desktop_application_group" "desktop" {
  name                = var.dag_name
  friendly_name       = "Desktop"
  resource_group_name = var.resource_group_name
  location            = var.location
  host_pool_id        = azurerm_virtual_desktop_host_pool.main.id
  type                = "Desktop"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "desktop" {
  workspace_id         = azurerm_virtual_desktop_workspace.main.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop.id
}

# ── RemoteApp Application Group (optional) ────────────────────────────────────
resource "azurerm_virtual_desktop_application_group" "remoteapp" {
  count               = var.create_rag ? 1 : 0
  name                = var.rag_name
  friendly_name       = "Remote Apps"
  resource_group_name = var.resource_group_name
  location            = var.location
  host_pool_id        = azurerm_virtual_desktop_host_pool.main.id
  type                = "RemoteApp"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "remoteapp" {
  count                = var.create_rag ? 1 : 0
  workspace_id         = azurerm_virtual_desktop_workspace.main.id
  application_group_id = azurerm_virtual_desktop_application_group.remoteapp[0].id
}

# ── RBAC: Desktop Virtualization User ─────────────────────────────────────────
data "azuread_group" "avd_users" {
  display_name = var.avd_users_group_name
}

resource "azurerm_role_assignment" "avd_users_desktop" {
  scope                = azurerm_virtual_desktop_application_group.desktop.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_users.object_id
}
