# VID – Vendor Independence Day

![Packer](https://img.shields.io/badge/HashiCorp%20Packer-1.9%2B-blue?style=for-the-badge&logo=packer&logoColor=white)
![Windows 11](https://img.shields.io/badge/Windows%2011-Enterprise-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Citrix](https://img.shields.io/badge/Citrix-MCS%20%7C%20PVS-green?style=for-the-badge)
![Horizon](https://img.shields.io/badge/VMware-Horizon-607078?style=for-the-badge&logo=vmware&logoColor=white)
![AVD](https://img.shields.io/badge/Azure-AVD-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)

Automatisierte, **broker-agnostische** Erstellung von Windows 11 Master-Images mit HashiCorp Packer. Unterstützte Zielplattformen:

| Broker | Technologie | Packer-Template |
|--------|-------------|-----------------|
| **Citrix MCS** | vSphere + Citrix VDA + MCS-Seal | `windows/desktop/11/` |
| **Citrix PVS** | vSphere + Citrix VDA + PVS-Prep | `windows/desktop/11/` |
| **VMware Horizon** | vSphere + Horizon Agent + IC-Prep | `windows/desktop/11/` |
| **Azure AVD** | Azure ARM + AVD RD Agent + FSLogix | `windows/desktop/11-avd/` |
| **Standalone** | vSphere, kein Broker | `windows/desktop/11/` |

## VID-Architektur – Layer-Modell

Das Projekt implementiert eine strikt getrennte 8-Schichten-Architektur. Jede Schicht kann unabhängig ausgetauscht werden:

| Layer | Inhalt | Broker-abhängig | Script |
|-------|--------|-----------------|--------|
| 5 | Windows 11 OS-Baseline, DSC-Härtung, Updates | ❌ Nein | `windows-dsc-apply.ps1` |
| 6 | Hypervisor-Treiber (VMware Tools / XenServer Tools) | ✅ Hypervisor | `windows-vmtools.ps1` |
| 7a | Broker Agent (VDA / Horizon Agent / AVD RD Agent) | ✅ Broker | `windows-*-agent/vda.ps1` |
| 7b | VDI-Optimierungen: generisch + broker-spezifisch | ✅ teilweise | `windows-vdi-optimize.ps1` + `windows-*-optimize.ps1` |
| 7c | Applikationen (PSADT → Winget → Chocolatey) | ❌ Nein | `windows-apps-install.ps1` |
| 7d | Active Directory Domain-Join (optional) | ❌ Nein | `windows-domain-join.ps1` |
| 7f | Finalize: MCS-Seal / IC-Prep / AVD-Cleanup | ✅ Broker | `windows-*-prep.ps1` |
| 8 | DEX Agent & Monitoring (ControlUp / uberagent) | ❌ Nein | *geplant* |

> **VID-Prinzip:** Layer 5 (OS) und Layer 7c (Apps) sind vollständig broker-agnostisch. Nur die Layer-7a/7b/7f-Scripts müssen beim Wechsel des Brokers ausgetauscht werden.

## Voraussetzungen

### Build-System (Linux/Ubuntu)

```bash
sudo apt update && sudo apt install -y packer xorriso git
```

### Packer-Plugins (werden via `packer init` automatisch geladen)

- [packer-plugin-vsphere](https://developer.hashicorp.com/packer/plugins/builders/vsphere/vsphere-iso) ≥ 1.2.0
- [packer-plugin-windows-update](https://github.com/rgl/packer-plugin-windows-update) ≥ 0.14.3
- [packer-plugin-git](https://github.com/ethanmdavidson/packer-plugin-git) ≥ 0.4.2
- [packer-plugin-azure](https://developer.hashicorp.com/packer/plugins/builders/azure) ≥ 2.0.0 *(nur für AVD)*

### vSphere-Infrastruktur (für Citrix/Horizon)

- vCenter Server mit API-Zugang
- Datastore ≥ 60 GB pro Build
- Windows 11 ISO auf dem Datastore
- VMware Tools ISO auf dem Datastore
- Netzwerk mit DHCP

### Azure (für AVD)

- Azure Subscription mit Contributor-Rolle auf Build-RG und Gallery-RG
- Service Principal (App Registration) mit Client-Secret
- Azure Compute Gallery (Shared Image Gallery) angelegt

### VID-Data SMB-Share

Zentrale Ablage für alle Build-Artefakte:

```
\\<server>\VID-Data\
  citrix\
    vda\          ← Citrix VDA Installer (VDAWorkstationSetup_2511.exe)
    optimize\     ← Optionale Custom-Optimierungsskripte
  vmware\
    horizon\      ← Horizon Agent Installer (VMware-Horizon-Agent-x86_64-*.exe)
  microsoft\
    avd\          ← AVD RD Agent (alternativ: Download via aka.ms/rdagent)
    fslogix\      ← FSLogix Apps (alternativ: Download via aka.ms/fslogix-latest)
  dex\
    controlup\    ← ControlUp Agent (Layer 8 – geplant)
    uberagent\    ← uberagent (Layer 8 – geplant)
  drivers\
    vmware\       ← Zusätzliche VMware-Treiber
  apps\           ← Business-App-Installer für PSADT-Pakete (Layer 7c)
```

## Konfiguration (vSphere – Citrix/Horizon)

### Schritt 1 – Konfigurationsdateien anlegen

```bash
cd packer/config
cp vsphere.pkrvars.hcl.example vsphere.pkrvars.hcl
cp build.pkrvars.hcl.example   build.pkrvars.hcl
cp sources.pkrvars.hcl.example sources.pkrvars.hcl
```

### Schritt 2 – vSphere-Verbindung (`vsphere.pkrvars.hcl`)

```hcl
vsphere_endpoint            = "vcenter.example.com"
vsphere_username            = "administrator@vsphere.local"
vsphere_password            = "DEIN_PASSWORT"
vsphere_insecure_connection = true
vsphere_datacenter          = "Datacenter"
vsphere_cluster             = "Cluster"
vsphere_datastore           = "datastore1"
vsphere_network             = "VM Network"
vsphere_folder              = "packer-builds"
```

### Schritt 3 – ISO-Quellen und SMB-Share (`sources.pkrvars.hcl`)

```hcl
common_iso_datastore  = "datastore1"
iso_path              = "iso"
iso_file              = "Win11_Enterprise_Eval.iso"
iso_checksum_type     = "sha256"
iso_checksum_value    = "CHECKSUM_DES_ISO"

vmtools_iso_path      = "/vmimages/tools-isoimages/windows.iso"

vid_smb_server        = "fileserver.example.com"
vid_smb_share         = "VID-Data"
vid_smb_username      = "DOMAIN\\svc-packer"   # Backslash verdoppeln!
vid_smb_password      = "DEIN_PASSWORT"

# Citrix
vid_vda_installer     = "VDAWorkstationSetup_2511.exe"

# Horizon (nur wenn vid_broker = "horizon")
vid_horizon_installer = "VMware-Horizon-Agent-x86_64-8.13.0-12345678.exe"
```

> **Tipp:** SHA256-Prüfsumme: `sha256sum Win11.iso` (Linux) oder `Get-FileHash Win11.iso -Algorithm SHA256` (PowerShell)

### Schritt 4 – Build-Account und Domain-Join (`build.pkrvars.hcl`)

```hcl
build_username = "adminst"
build_password = "DEIN_PASSWORT"

domain_join_enabled       = true
domain_name               = "corp.example.com"
domain_join_username      = "svc-packer@corp.example.com"
domain_join_password      = "DEIN_PASSWORT"
domain_join_ou            = "OU=GoldenImage,OU=VDI,OU=Clients,DC=corp,DC=example,DC=com"
domain_join_computer_name = "VID-W11-BUILD"   # leer = Windows-generierter Name
```

### Schritt 5 – Broker auswählen (`windows.auto.pkrvars.hcl`)

Die Broker-Auswahl steuert, welche Layer-7a/7b/7f-Steps ausgeführt werden:

```hcl
vid_broker = "citrix-mcs"   # citrix-mcs | citrix-pvs | horizon | none
```

## Konfiguration (Azure AVD)

Erstelle `packer/windows/desktop/11-avd/build.pkrvars.hcl` (nicht im Repo):

```hcl
# Azure Authentication (Service Principal)
azure_client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_client_secret   = "DEIN_SECRET"
azure_tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Build-Infrastruktur
azure_build_resource_group  = "rg-vid-build"
azure_build_storage_account = "stvidpacker"
azure_gallery_resource_group = "rg-vid-gallery"
azure_gallery_name           = "gal_vid_images"

# Build-Credentials
build_username = "adminst"
build_password = "DEIN_PASSWORT"
```

## Applikationen konfigurieren

Die App-Installation wird über `packer/scripts/windows/apps-manifest.json` gesteuert.  
Installer-Priorität: **PSADT** → **Winget (pinned)** → **Chocolatey**

```json
{
  "groups": [
    {
      "group": "Productivity",
      "enabled": true,
      "apps": [
        {
          "name": "7-Zip",
          "enabled": true,
          "psadt_path": "psadt/packages/7-Zip",
          "winget": "7zip.7zip",
          "winget_version": "24.08.0.0",
          "chocolatey": "7zip"
        }
      ]
    }
  ]
}
```

PSADT-Pakete liegen unter `packer/scripts/windows/psadt/packages/`. Das Framework (`psadt/_framework/`) und das Deploy-Script werden beim Build automatisch zusammengeführt.

## Build starten

### vSphere (Citrix / Horizon)

```bash
# Vom Repository-Root:
./build.sh w11-base    # Layer 5+6: OS + VMware Tools + Updates (schnellster Test)
./build.sh w11-full    # Layer 5+6+7c+7d: Alles ohne Broker-Agent
./build.sh w11-vda     # Vollständiges Master-Image (Broker via vid_broker-Variable)
```

### Azure AVD

```bash
cd packer/windows/desktop/11-avd
packer init .
packer build -var-file="build.pkrvars.hcl" .
```

### Build-Targets (vSphere)

| Target | Layer | `vid_broker` | Verwendung |
|--------|-------|--------------|------------|
| `w11-base` | 5+6 | *ignoriert* | Schneller Infrastrukturtest |
| `w11-full` | 5+6+7c+7d | `none` | Test ohne Broker-Lizenz |
| `w11-vda` | 5–7f | `citrix-mcs` | Citrix MCS Master-Image (Produktion) |
| `w11-vda` | 5–7f | `citrix-pvs` | Citrix PVS vDisk-Image |
| `w11-vda` | 5–7f | `horizon` | VMware/Broadcom Horizon IC-Image |

### Build-Pipeline (`w11-vda`, `vid_broker = "citrix-mcs"`)

| # | Schritt | Script | Layer |
|---|---------|--------|-------|
| 1 | Windows 11 Installation | `autounattend.pkrtpl.hcl` | 5 |
| 2 | VMware Tools | `windows-vmtools.ps1` | 6 |
| 3 | WinRM-Init | `windows-init.ps1` | 5 |
| 4 | OS-Baseline DSC | `windows-dsc-apply.ps1` | 5 |
| 5 | Windows Updates (pre-Agent) | *(windows-update Plugin)* | 5 |
| 6 | Domain-Join (optional) + Neustart | `windows-domain-join.ps1` | 5→7 |
| 7a | Citrix VDA | `windows-citrix-vda.ps1` | 7a |
| 8 | Neustart | — | 7a |
| 9 | Windows Updates (post-Agent) | *(windows-update Plugin)* | 7a |
| 10 | App-Installation | `windows-apps-install.ps1` | 7c |
| 11 | Generische VDI-Optimierungen | `windows-vdi-optimize.ps1` | 7b |
| 11a | Citrix-spezifische Optimierungen | `windows-citrix-optimize.ps1` | 7b |
| 12a | MCS/PVS Master Image Seal | `windows-citrix-mcs-prep.ps1` | 7f |
| 13 | Event-Log-Cleanup | *(inline)* | Finalize |

> **Hinweis:** Bei `vid_broker = "horizon"` werden Step 7a → `windows-horizon-agent.ps1`, Step 11a → `windows-horizon-optimize.ps1` und Step 12 → `windows-horizon-ic-prep.ps1` verwendet. Steps 11 (generisch) und 10 (Apps) bleiben identisch.

> Build-Dauer: typischerweise **60–90 Minuten** (abhängig von Windows Updates).

### Debug-Modus

```bash
PACKER_LOG=1 PACKER_LOG_PATH=packer-debug.log ./build.sh w11-vda
```

## Verzeichnisstruktur

```
.
├── build.sh                                  # Einstiegspunkt (Repo-Root)
├── CHANGELOG.md
├── packer/
│   ├── create_templates.sh                   # Internes Build-Skript
│   ├── config/
│   │   ├── vsphere.pkrvars.hcl(.example)     # vCenter-Credentials
│   │   ├── build.pkrvars.hcl(.example)       # Build-Account + Domain-Join
│   │   ├── sources.pkrvars.hcl(.example)     # ISO-Pfade + SMB-Share
│   │   └── common.pkrvars.hcl
│   ├── scripts/windows/
│   │   ├── dsc/
│   │   │   └── VID-OSBaseline.ps1            # PowerShell DSC – OS-Baseline (Layer 5)
│   │   ├── psadt/
│   │   │   ├── _framework/                   # XOAP PSADT Framework 3.9.2
│   │   │   ├── _template/                    # VID Deploy-Application.ps1 Template
│   │   │   └── packages/                     # App-Pakete (7-Zip, Adobe Reader, ...)
│   │   ├── windows-dsc-apply.ps1             # DSC Runner / Packer Bootstrap (Layer 5)
│   │   ├── windows-init.ps1                  # WinRM-Initialisierung (Layer 5)
│   │   ├── windows-vmtools.ps1               # VMware Tools (Layer 6)
│   │   ├── windows-domain-join.ps1           # AD Domain-Join (Layer 7d)
│   │   ├── windows-apps-install.ps1          # App-Orchestrator: PSADT/Winget/Choco (Layer 7c)
│   │   ├── apps-manifest.json                # App-Konfiguration (alle Broker)
│   │   ├── windows-vdi-optimize.ps1          # Generische VDI-Optimierungen – ALLE Broker (Layer 7b)
│   │   ├── windows-citrix-vda.ps1            # Citrix VDA Installation (Layer 7a)
│   │   ├── windows-citrix-optimize.ps1       # Citrix-spezifische Tweaks (Layer 7b)
│   │   ├── windows-citrix-mcs-prep.ps1       # Citrix MCS/PVS Master Image Seal (Layer 7f)
│   │   ├── windows-horizon-agent.ps1         # Horizon Agent Installation (Layer 7a)
│   │   ├── windows-horizon-optimize.ps1      # Horizon-spezifische Tweaks (Layer 7b)
│   │   ├── windows-horizon-ic-prep.ps1       # Horizon Instant Clone IC-Prep (Layer 7f)
│   │   ├── windows-avd-agent.ps1             # AVD RD Agent + BootLoader (Layer 7a)
│   │   └── windows-avd-fslogix.ps1           # FSLogix Profil-Container (Layer 7b)
│   └── windows/desktop/
│       ├── 11/                               # vSphere-Template (Citrix + Horizon)
│       │   ├── windows.pkr.hcl               # Haupt-Packer-Template (multi-broker)
│       │   ├── variables.pkr.hcl             # Variablen-Definitionen
│       │   ├── windows.auto.pkrvars.hcl      # VM-Hardware + vid_broker
│       │   └── data/autounattend.pkrtpl.hcl  # Windows-Antwortdatei
│       ├── 11-avd/                           # Azure ARM-Template (AVD)
│       │   ├── windows.pkr.hcl               # AVD Packer-Template (azure-arm Builder)
│       │   └── variables.pkr.hcl             # Azure-Variablen + Gallery
│       └── 11-xenserver/                     # XenServer/Citrix Hypervisor (WIP)
├── citrix-mcs/
│   ├── deploy-citrix-mcs.ps1                 # MCS-Deployment
│   └── update-image.ps1                      # Image-Update in Citrix DaaS
└── Vendor-Independence-Day-Architekturkonzept-v1.0.md
```

## VDI Optimize – Schicht-Modell

Die VDI-Optimierungen sind in generisch + broker-spezifisch aufgeteilt:

| Script | Layer | Broker | Inhalt |
|--------|-------|--------|--------|
| `windows-vdi-optimize.ps1` | 7b | **ALL** | Power Plan, Services, Scheduled Tasks, Telemetrie, OneDrive, Netzwerk, Storage, AppX, Visual/UI, Event Logs, Terminal Services |
| `windows-citrix-optimize.ps1` | 7b | citrix-mcs, citrix-pvs | Defender Exclusions für Citrix-Pfade, CtxHook Registry, EDT/UDT-Protokoll |
| `windows-horizon-optimize.ps1` | 7b | horizon | Blast Extreme Tweaks, DPI-Sync, OSOT-Referenz |
| *(kein separates Script)* | — | avd | Generisches Script reicht (kein AVD-spezifisches Optimize nötig) |

## Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| `xorriso` nicht gefunden | Paket fehlt | `sudo apt install -y xorriso` |
| `Invalid escape sequence` | Einfacher Backslash in HCL | `DOMAIN\\user` statt `DOMAIN\user` |
| `Unsupported attribute` | Veralteter Git-Stand auf Build-VM | `git pull` auf der Build-VM |
| `apps-manifest.json not found` | Datei nicht hochgeladen | Bereits gefixt – `file`-Provisioner läuft vor App-Script |
| `timeout waiting for IP` | VMware Tools fehlen / ISO-Pfad falsch | `vmtools_iso_path` in `sources.pkrvars.hcl` prüfen |
| Build hängt bei Windows Updates | Normal – dauert 15–45 Min | Warten, ggf. `restart_timeout` erhöhen |
| Domain-Join schlägt fehl | Computer-Account existiert bereits | Alten Account im AD löschen |
| DSC `Test-DscConfiguration` = False | Ressourcen-Drift im WinRM-Kontext | Log prüfen: `C:\Windows\Logs\VID\vid-dsc-baseline.log` |
| Horizon Agent-Installation schlägt fehl | `vid_horizon_installer` nicht gesetzt | Dateiname des Installers in `windows.auto.pkrvars.hcl` eintragen |

## Sicherheit

- **Passwörter** werden niemals committed – alle sensitiven `.pkrvars.hcl` sind in `.gitignore`
- Für CI/CD: Umgebungsvariablen mit `PKR_VAR_`-Prefix verwenden (z.B. `PKR_VAR_build_password`)
- Der Build-Account (`adminst`) wird nur während des Builds benötigt
- SMB-Zugang mit expliziten Credentials – kein Domain-Join der Build-VM erforderlich
- Azure: Service Principal mit minimalen Rechten (Contributor nur auf Build-RG + Gallery-RG)
- VID-Sentinel: Erfolgreiche Anwendung aller Scripts wird in `HKLM:\SOFTWARE\VendorIndependenceDay\` dokumentiert

## Dokumentation

- [CHANGELOG.md](CHANGELOG.md) – Release-History
- [Vendor-Independence-Day-Architekturkonzept-v1.0.md](Vendor-Independence-Day-Architekturkonzept-v1.0.md) – Architektur-Konzept
