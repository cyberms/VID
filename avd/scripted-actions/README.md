# AVD Scripted Actions

Operative PowerShell-Scripts für die Azure Virtual Desktop (AVD) Infrastruktur.
Basierend auf xoap-io scripted-actions, angepasst für den VID-Kontext.

## Voraussetzungen

```powershell
Install-Module -Name Az -Scope CurrentUser -Force
Install-Module -Name Az.DesktopVirtualization -Scope CurrentUser -Force
Connect-AzAccount
```

## Reihenfolge beim initialen AVD-Setup

| Schritt | Script | Beschreibung |
|---------|--------|--------------|
| 1 | `az-ps-create-resource-group.ps1` | Resource Group anlegen |
| 2 | `az-ps-create-virtual-network.ps1` | VNet + Subnet für Session Hosts |
| 3 | `az-ps-create-storage-account.ps1` | Storage für FSLogix Profile Container |
| 4 | `az-ps-create-key-vault.ps1` | Key Vault für Secrets |
| 5 | `az-ps-set-key-vault-secret.ps1` | Secrets hinterlegen (Domain-Join etc.) |
| 6 | `az-ps-create-avd-hostpool.ps1` | Host Pool (Pooled / Personal) |
| 7 | `az-ps-create-avd-registration-info.ps1` | Registration Token generieren |
| 8 | `az-ps-create-avd-application-group.ps1` | Desktop Application Group |
| 9 | `az-ps-create-avd-workspace.ps1` | Workspace |
| 10 | `az-ps-register-avd-application-group.ps1` | App Group → Workspace verknüpfen |
| 11 | *(Packer-Build + terraform/avd)* | Session Host VMs aus Image provisionieren |
| 12 | `az-ps-assign-vm-to-avd-hostpool.ps1` | Session Hosts registrieren |

## Lifecycle-Management

- `az-ps-update-avd-hostpool.ps1` – Host Pool Properties ändern (MaxSessionLimit, RDP-Properties)
- `az-ps-update-avd-session-host.ps1` – Session Host (Drain Mode, Friendly Name)
- `az-ps-remove-avd-session-host.ps1` – Session Host entfernen (nach Image-Update)
- `az-ps-send-avd-user-session-message.ps1` – Benutzer benachrichtigen (vor Reboot/Drain)
- `az-ps-remove-avd-user-session.ps1` – Sitzung beenden
- `az-ps-remove-avd-registration-info.ps1` – Token löschen

## VID-Integration

Diese Scripts ergänzen die Terraform-Konfiguration unter `terraform/avd/` (Phase 2).
Terraform übernimmt den initialen Infrastructure-Aufbau,
diese Scripts dienen dem operativen Tagesbetrieb (Drain, Update, Skalierung).
