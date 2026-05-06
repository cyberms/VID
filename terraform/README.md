# VID – Terraform Module Übersicht

Dieser Ordner enthält alle Terraform-Konfigurationen für die VID-Infrastruktur.
Jeder Unterordner ist ein eigenständiges Terraform-Modul mit eigenem State.

## Module und Status

| Modul | Plattform | Phase | Status | Voraussetzungen |
|-------|-----------|-------|--------|-----------------|
| [`citrix/`](citrix/) | Citrix DaaS / vSphere | 1b | ✅ **Aktiv** | CC vorinstalliert, vSphere Hosting Connection vorhanden |
| [`citrix-resource-location/`](citrix-resource-location/) | Citrix DaaS / vSphere | 1c | 🔧 **Scaffold** | vSphere 8, AD-Domain, Citrix Cloud Account |
| [`horizon/`](horizon/) | VMware Horizon / vSphere | 2 | 📋 **Geplant** | vSphere 8, Horizon Lizenz, AD-Domain |
| [`avd/`](avd/) | Azure Virtual Desktop | 2 | 📋 **Geplant** | Azure Subscription, AD/Entra ID, Azure Compute Gallery |

## Reihenfolge und Abhängigkeiten

```
Voraussetzung (manuell oder Phase 1c):
  citrix-resource-location/     ← Cloud Connectors auf vSphere registrieren
  ↓
Phase 1b (aktiv):
  citrix/                       ← Machine Catalog + Delivery Group
  ↓
Packer-Build:
  ./build.sh <broker>           ← Master Image erstellen
  ↓
Image-Update:
  citrix/update-image.sh        ← Neues Image in Catalog einspielen
```

## Aktueller Betrieb (CCs vorinstalliert)

Für den normalen Betrieb werden die Cloud Connectors als **bereits installiert und registriert**
vorausgesetzt. Das Modul `citrix-resource-location/` ist optional und dient der vollständigen
Automatisierung bei Neuaufbau einer Resource Location.

```bash
# Einmalig: Machine Catalog + Delivery Group anlegen
cd terraform/citrix
cp terraform.tfvars.example terraform.tfvars   # Credentials eintragen
terraform init
terraform apply

# Nach jedem Packer-Build: Image aktualisieren
./update-image.sh
```

## Geplante Erweiterungen

### Phase 1c – Citrix Resource Location (citrix-resource-location/)
Vollständige Automatisierung des Cloud Connector Deployments auf vSphere:
- Modul 1: CC-VMs + Admin-VM in vSphere erstellen (vmware/vsphere Provider)
- Modul 2: Cloud Connector Software + CitrixPoshSdk installieren, CCs registrieren (WinRM)
- Modul 3: Hypervisor Connection + Resource Pool in Citrix Cloud anlegen (citrix Provider)

Referenz: [Citrix Deployment Guide – Terraform vSphere Resource Location](https://community.citrix.com/tech-zone/build/deployment-guides/)

### Phase 2 – Horizon (horizon/)
VMware Horizon Connection Server Infrastruktur:
- Horizon Connection Server VMs in vSphere (vmware/vsphere Provider)
- Horizon Instant Clone Pool + Entitlements (via Horizon REST API / PowerShell)
- Integration mit bestehenden Packer-Images (`vid_broker=horizon`)

### Phase 2 – AVD (avd/)
Azure Virtual Desktop vollständige IaC-Lösung:
- Resource Group, VNet, Key Vault, Storage Account (azurerm Provider)
- Azure Compute Gallery + Image Definition für Packer-Output
- Host Pool + Application Group + Workspace (azurerm desktopvirtualization)
- Session Host VMs aus Compute Gallery Image

Operative Scripts bereits verfügbar: [`avd/scripted-actions/`](../avd/scripted-actions/)

## Tool-Stack

Citrix empfiehlt (Citrix Automation Handbook 2601) den folgenden Triad:

```
Packer   → Master Images (golden images, alle Broker)
Terraform → Infrastruktur (VMs, Netzwerk, Citrix/Horizon/AVD Ressourcen)
Ansible   → Konfiguration die Terraform nicht kann (Domain Join, WinRM-Provisioning)
GitHub    → Source of Truth, CI/CD, Pull Requests
```

Aktueller VID-Stand: Packer ✅ + Terraform ✅ | Ansible: Phase 3+
