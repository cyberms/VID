# Release History

## v2.1 – 2026-05-06

### Neu – terraform/citrix-resource-location/ Scaffold (Phase 1c)

Vollständige 3-Modul-Struktur für Citrix Cloud Connector Provisioning auf vSphere (SCAFFOLD-Status):

- **module-1-vsphere**: Cloud Connector VMs + Admin-VM in vSphere anlegen
  - vsphere Provider (hashicorp/vsphere >= 2.7.0)
  - Domain Join + WinRM-Aktivierung via `run_once_command_list`
  - 2× CC-VMs (VID-CC-01/02), 1× Admin-VM, konfigurierbar
- **module-2-install**: Cloud Connector Software + CitrixPoshSdk via WinRM installieren
  - null_resource mit WinRM-Connection zu CC-VMs
  - `cwcconnector.exe` Silent-Install, `CitrixPoshSdk.exe`
  - `citrix_zone` Resource = Citrix Cloud Resource Location
  - Output: `resource_location_id`
- **module-3-hypervisor**: Hosting Connection + Resource Pool in Citrix Cloud
  - `citrix_hypervisor` (VCenter-Typ) + `citrix_hypervisor_resource_pool`
  - Outputs: `hypervisor_id`, `hypervisor_resource_pool_id` → in `terraform/citrix/terraform.tfvars` eintragen

### Neu – terraform/horizon/ Scaffold (Future Phase)

3-Modul-Struktur für VMware Horizon Infrastruktur (SCAFFOLD-Status, Future Phase):

- **module-1-vsphere**: Horizon Connection Server VMs (Primary + Replica) in vSphere
  - vsphere Provider, WinRM-Aktivierung via `run_once_command_list`
  - Konfigurierbar: VM-Count, CPU, Memory, Netzwerk, AD Domain Join
- **module-2-install**: Horizon Connection Server Silent-Install via WinRM
  - null_resource mit WinRM, Installer-Download + Ausführung
  - Unterschiedliche Installer-Args für Primary (`INSTANCE_TYPE=1`) und Replica (`INSTANCE_TYPE=2`)
- **module-3-config**: Horizon-Konfiguration via REST API (SCAFFOLD)
  - Hinweis: Kein offizieller Terraform-Provider für Horizon vorhanden
  - Geplant: vCenter-Hosting, Desktop Pools (Instant Clone), Entitlements via Horizon REST API
  - Phase 3+ empfohlen: Ansible VMware Horizon Collection

### Neu – terraform/avd/ Scaffold (Future Phase)

3-Modul-Struktur für Azure Virtual Desktop Infrastruktur (SCAFFOLD-Status, Future Phase):

- **module-1-azure-infra**: Azure Basisinfrastruktur
  - azurerm + azuread Provider
  - Resource Group, VNet, Subnets (Session Hosts, MGMT)
  - Network Security Group (RDP aus Internet gesperrt, AVD ServiceTag erlaubt)
- **module-2-hostpool**: AVD Host Pool, Workspace, Application Groups
  - `azurerm_virtual_desktop_host_pool` (Pooled/Personal, BreadthFirst/DepthFirst)
  - `azurerm_virtual_desktop_workspace` + Desktop Application Group
  - Optionale RemoteApp Application Group
  - RBAC: Desktop Virtualization User Role für AAD-Nutzergruppe
  - Registration Token via `time_rotating` Resource (2h Rotation)
- **module-3-sessionhosts**: Session Host VMs
  - Windows VMs aus VID Packer-Image (Azure Compute Gallery oder Managed Image)
  - Domain Join Extension (Hybrid ADDS oder Azure AD Join)
  - AVD Agent + Bootloader via DSC Extension

### Neu – terraform/README.md + terraform/citrix-resource-location/README.md

Übersichts-Dokumentation der gesamten Terraform-Landschaft:
- Modul-Tabelle mit Status, Phase, Voraussetzungen
- Reihenfolge-Diagramm (citrix-resource-location → citrix → Packer → update-image)
- Tool-Stack-Dokumentation: Packer ✅ + Terraform ✅ | Ansible Phase 3+
- Betriebshinweise für CCs-vorinstalliert-Modus

---

## v2.0 – 2026-05-06

### Neu – xoap-Abgleich: windows-vdi-optimize.ps1 angereichert

Abgleich mit `xoap-image-management-templates-master/scripts/w11/windows11-Optimize_W11_25H2.ps1`:

- **16 zusätzliche Services deaktiviert** (Sektion [3]):
  - Mobile/Location: `icssvc`, `lfsvc`, `autotimesvc`
  - Sync/Messaging: `OneSyncSvc`, `MessagingService`, `WalletService`, `PimIndexMaintenanceSvc`, `TabletInputService`
  - Hardware (nicht in VMs): `WbioSrvc`, `SCardSvr`, `DsmSvc`, `DusmSvc`, `SSDPSRV`
  - Netzwerk/Druck: `WMPNetworkSvc`, `Spooler`
  - Sonstiges: `CscService` (Offline Files), `wisvc` (Windows Insider)
- **Neue Sektion [3b] – WMI Autologger**: 9 Boot-Tracing-Sitzungen deaktiviert
  (`AppModel`, `CloudExperienceHostOOBE`, `DiagLog`, `ReadyBoot`, `WDIContextLog`, `WiFiDriverIHVSession`, `WiFiSession`, `Cellcore`, `WinPhoneCritical`)
- **5 zusätzliche Scheduled Tasks** deaktiviert (Sektion [4]):
  `PcaPatchDbTask`, `Device Information\Device`, `DiskCleanup\SilentCleanup`, `Location\Notifications`, `Location\WindowsActionDialog`
- **Registry-Ergänzungen**:
  - WU: `NoAutoRebootWithLoggedOnUsers = 1`
  - Telemetrie: `AllowGameDVR = 0`
  - Netzwerk: `NetworkThrottlingIndex = 4294967295`, `SystemResponsiveness = 0` (Multimedia SystemProfile)

### Neu – windows-citrix-pvs-prep.ps1

Vollständige Implementierung für Citrix PVS Master Image Vorbereitung (Layer 7f):
- PVS-spezifische Services: `Fax`, `RemoteRegistry`, `PhoneSvc`, `WcnSvc`, `StiSvc`, `FrameServer`, `seclogon`
- Windows Update → Manual (PVS streamt vDisk)
- Page File: automatisch managed (WMI + Registry-Fallback)
- Optionaler PVS Target Device Software-Install via `$PvsInstallerPath` / `VID_PVS_INSTALLER_PATH`
- ScheduledDefrag deaktiviert
- VID Sentinel: `HKLM:\SOFTWARE\VendorIndependenceDay\Provisioning\PVSPrepApplied`
- Basiert auf: xoap `windows11-Prepare_For_Citrix_PVS.ps1` + Citrix PVS Best Practices

### Neu – avd/scripted-actions/ (operative Azure PS-Scripts)

21 Azure PowerShell Scripts für AVD-Betrieb aus xoap `scripted-actions-master`:
- Setup: Resource Group, VNet, Storage, Key Vault, Host Pool, Registration Token, App Group, Workspace
- Lifecycle: Update/Remove Host Pool, Session Host Drain, User Session Management
- Quelle: `xoap-io/scripted-actions` (xoap.io)
- Zweck: Operativer Betrieb (Ergänzung zu terraform/avd/ Phase 2)
- Voraussetzung: `Az` + `Az.DesktopVirtualization` PowerShell Module

### Referenz – Citrix_Data/ (offizielle Citrix Deployment Guides)

Hinzugefügt als Referenzmaterial (nicht commitet – außerhalb Repo):
- **Citrix Automation Handbook 2601** (6 Teile) – IaC-Strategie mit Packer + Terraform + Ansible + GitHub
- **CVAD 2507 LTSR on vSphere 8** – Vollständiger IaC-Deployment-Guide (Packer → Terraform → Ansible)
- **Terraform vSphere Resource Location** – 3-Modul-Ansatz für Cloud Connector Provisioning

**Erkenntnisse für VID-Roadmap:**
- `terraform/citrix/` (Phase 1b) ✅ = Machine Catalog + Delivery Group (korrekt)
- Phase 1c (geplant): `terraform/citrix-resource-location/` = Cloud Connector Provisioning auf vSphere (Modul-Ansatz gemäß Citrix Guide)
- Citrix empfiehlt **Packer + Terraform + Ansible** Triad – Ansible für Konfiguration die Terraform nicht übernehmen kann (z.B. Domain Join, CC-Registrierung via WinRM)

---

## v1.9 – 2026-05-06

### Neue Features – Terraform Phase 1b: Citrix DaaS Infrastructure as Code

- **`terraform/citrix/providers.tf`** – Citrix Terraform Provider `~> 1.0` mit Cloud-Authentifizierung
- **`terraform/citrix/variables.tf`** – Vollständige Variablen-Deklaration (Credentials, Zone, Hypervisor, Image, Netzwerk, Catalog, Delivery Group)
- **`terraform/citrix/main.tf`** – Machine Catalog (MCS, nicht-persistent) + Delivery Group mit Autoscale
  - `citrix_machine_catalog`: Random allocation, MCS-Provisioning, Write-Back-Cache, AD-Naming-Schema
  - `citrix_delivery_group`: Desktop-Veröffentlichung, AD-Gruppen-Zugriff, Autoscale (Mo–Fr 07:00–18:00)
- **`terraform/citrix/outputs.tf`** – Outputs: catalog_id, delivery_group_id, master_image_vm, vm_count
- **`terraform/citrix/terraform.tfvars.example`** – Kommentierte Beispielkonfiguration mit allen Pflichtfeldern
- **`terraform/citrix/update-image.sh`** – Wrapper-Script für Image-Updates nach Packer-Build
  - Liest `packer/windows/desktop/11/output/manifest.json` automatisch (jq)
  - Konstruiert XDHyp-Pfad aus Manifest + bestehender `terraform.tfvars`
  - Flags: `--dry-run`, `--image`, `--catalog`, `--manifest`
  - Validiert Voraussetzungen: terraform, jq, terraform.tfvars

### Deprecated – PowerShell-Scripts als Legacy markiert

- **`citrix-mcs/deploy-citrix-mcs.ps1`** → DEPRECATED, ersetzt durch `terraform/citrix/main.tf`
- **`citrix-mcs/update-image.ps1`** → DEPRECATED, ersetzt durch `terraform/citrix/update-image.sh`
- Beide Scripts erhalten einen deutlichen Legacy-Header mit Hinweis auf die Terraform-Alternativen
- Scripts bleiben als Fallback erhalten, werden nicht mehr aktiv weiterentwickelt

### Terraform Quickstart

```bash
cd terraform/citrix
cp terraform.tfvars.example terraform.tfvars   # Werte eintragen
terraform init
terraform apply

# Nach jedem Packer-Build:
./update-image.sh                    # Auto-Manifest
./update-image.sh --dry-run          # Nur Plan
./update-image.sh --image "XDHyp:\..." # Manueller Pfad
```

---

## v1.8 – 2026-05-05

### Neue Features – Broker-agnostische VDI Optimierungen

- **Generic VDI Optimize**: `windows-vdi-optimize.ps1` – neues broker-agnostisches Script für **alle** Broker (citrix-mcs, citrix-pvs, horizon, avd, none)
  - Power Plan, Page File, Services, Scheduled Tasks, Windows Update Policy
  - Telemetrie & Datenschutz, OneDrive, Netzwerk (NIC, LSO, TCP, DNS)
  - Storage/Filesystem, SmartScreen, Visual/UI, AppX Bloatware
  - Event Log Sizing, WER, Zeitzone, Terminal Services, Startup Cleanup
  - VID Sentinel: `HKLM:\SOFTWARE\VendorIndependenceDay\Optimization\VDIOptimizeApplied`

### Geändert – Optimierungen aufgeteilt nach Schicht-Prinzip

- **`windows-citrix-optimize.ps1`** – auf Citrix-spezifische Tweaks reduziert:
  - Defender Exclusions für `%ProgramFiles%\Citrix`, `%ProgramData%\Citrix`, `Temp\Citrix*`
  - Citrix CtxHook Registry, EDT/UDT-Protokoll, DWM Flip3d
- **`windows-horizon-optimize.ps1`** – auf Horizon-spezifische Tweaks reduziert:
  - Blast Extreme Encoder-Qualität, DPI-Synchronisierung
  - OSOT (VMware OS Optimization Tool) – auskommentierter Referenz-Aufruf

### Geändert – Packer Templates

- **`windows/desktop/11/windows.pkr.hcl`**:
  - Step 11 NEU (ALL broker): `windows-vdi-optimize.ps1`
  - Step 11a (Citrix): schlankes `windows-citrix-optimize.ps1`
  - Step 11b (Horizon): schlankes `windows-horizon-optimize.ps1`
  - Header-Kommentar: vollständige Build-Pipeline für alle Broker dokumentiert
- **`windows/desktop/11-avd/windows.pkr.hcl`**:
  - Step 6b NEU: `windows-vdi-optimize.ps1` (nach FSLogix, vor Apps)

### VDI Optimize Schicht-Modell (aktualisiert)
| Script | Layer | Broker |
|--------|-------|--------|
| `windows-vdi-optimize.ps1` | 7b | **ALL** (citrix/horizon/avd/none) |
| `windows-citrix-optimize.ps1` | 7b | citrix-mcs, citrix-pvs |
| `windows-horizon-optimize.ps1` | 7b | horizon |
| *(kein separates AVD-Optimize-Script)* | – | AVD (generic reicht) |

---

## v1.7 – 2026-05-05

### Neue Features – Broker-Abstraktion (AVD + Horizon)
- **Horizon Agent**: `windows-horizon-agent.ps1` – Stub für VMware/Broadcom Horizon Agent (Instant Clone)
- **Horizon Optimize**: `windows-horizon-optimize.ps1` – VDI-Optimierungen für Horizon (SysMain, WSearch, OneDrive)
- **Horizon IC-Prep**: `windows-horizon-ic-prep.ps1` – Instant Clone Master Image Finalize (analog MCS-Prep)
- **AVD Agent**: `windows-avd-agent.ps1` – RD Agent + BootLoader für Azure Virtual Desktop
- **FSLogix**: `windows-avd-fslogix.ps1` – FSLogix Profil-Container für AVD (Citrix UPM-Äquivalent)
- **AVD Packer-Template**: `windows/desktop/11-avd/` – Eigenes Template mit `azure-arm` Builder, Azure Compute Gallery, Shared Image Gallery

### Geändert – Broker-Agnostik in `windows.pkr.hcl`
- **`build_include_citrix` DEPRECATED**: Alle `for_each`-Bedingungen auf `vid_broker`-Vergleiche umgestellt
  - Citrix-Schritte: `vid_broker == "citrix-mcs" || vid_broker == "citrix-pvs"`
  - Horizon-Schritte: `vid_broker == "horizon"` (NEU)
  - AVD: eigenes Template `11-avd/` (azure-arm, nicht in diesem Template)
- **Neue Provisioner-Blöcke**: Step 7b (Horizon Agent), Step 11b (Horizon Optimize), Step 12b (Horizon IC-Prep)
- **`vid_horizon_installer`**: Neue Variable für den Horizon Agent Dateinamen auf dem SMB-Share

### VID Layer-Prinzip (bestätigt)
| Schicht | Inhalt | Broker-abhängig? |
|---------|--------|-----------------|
| 5 – OS Baseline (DSC) | TLS, Hibernate, Power Plan, ... | ❌ Nein |
| 6 – Hypervisor Drivers | VMware Tools / XenServer Tools | ✅ Hypervisor |
| 7a – Broker Agent | Citrix VDA / Horizon Agent / AVD RD Agent | ✅ Broker |
| 7b – Optimierungen | Citrix Optimizer / OSOT / AVD Tweaks | ✅ Broker |
| 7c – Apps (PSADT) | 7-Zip, Reader, Office, ... | ❌ Nein |
| 8 – DEX (geplant) | ControlUp / uberagent | ❌ Nein |

---

## v1.6 – 2026-05-05

### Neue Features
- **DSC OS-Baseline**: `dsc/VID-OSBaseline.ps1` ersetzt `windows-prepare.ps1` als idempotente, auditierbare PowerShell DSC-Konfiguration für Layer 5
  - TLS 1.0 / TLS 1.1 deaktiviert (SCHANNEL, Client + Server)
  - Hibernation und Fast Startup deaktiviert (VDA-Kompatibilität)
  - Windows Fehlerberichterstattung (WER) deaktiviert
  - Power Plan: High Performance (VDI-Best-Practice)
  - Windows Search (WSearch) Dienst deaktiviert (Performance)
  - Passwort läuft nie ab: lokale Admin-Accounts + Build-User
  - Default User Hive: Explorer-Einstellungen für alle neuen Benutzer (NTUSER.DAT Mount)
  - VID-Sentinel: Erfolgreiche Anwendung in `HKLM:\SOFTWARE\VendorIndependenceDay\DSC\` dokumentiert
- **DSC-Runner**: `windows-dsc-apply.ps1` Bootstrap-Script für Packer-Integration
  - LCM auf `ApplyOnly` + `Push` (kein Pull-Server erforderlich)
  - MOF-Kompilierung nach `C:\Windows\Temp\VID-DSC\`
  - `Test-DscConfiguration` für Compliance-Verifikation nach Apply
  - Logging nach `C:\Windows\Logs\VID\vid-dsc-baseline.log`

### Geändert
- **`scripts_layer5`**: `windows-prepare.ps1` → `windows-dsc-apply.ps1` (deprecated)
- **`windows.auto.pkrvars.hcl`**: Kommentar auf DSC-Baseline aktualisiert

### Referenzen
- Citrix Automation Handbook 2601 (Gerhard Krenn): Triad-Strategie (Packer + Terraform + Ansible) bestätigt VID-Architektur; Terraform-Provider für MCS/DaaS relevant für nächste Phase

---

## v1.5 – 2026-03-30

### Neue Features
- **PSADT-Framework**: XOAP PSADT Framework Template 3.9.2 als Grundlage für VID App-Pakete (`psadt/_framework/`)
- **PSADT-Template**: VID-angepasstes `Deploy-Application.ps1` Template für neue Pakete (`psadt/_template/`)
- **PSADT-Pakete**: Beispielpakete für 7-Zip 24.08.0 und Adobe Reader 24.5.0 (`psadt/packages/`)
- **VID-Extensions**: `AppDeployToolkitExtensions.ps1` schreibt App-Metadaten nach `HKLM:\SOFTWARE\VendorIndependenceDay\InstalledApps\`
- **Installer-Priorität**: PSADT → Winget (pinned) → Chocolatey
- **Versionspinning**: `winget_version` in `apps-manifest.json` (v2.0.0) für reproduzierbare Builds

### Geändert
- **`apps-manifest.json`**: Version 2.0.0 – neues Feld `psadt_path` und `winget_version` pro App
- **`windows-apps-install.ps1`**: Orchestrator komplett überarbeitet; unterstützt jetzt PSADT als primären Installer; PSADT-Pakete werden in Temp-Verzeichnis zusammengeführt (Framework + Deploy-Script + Files) und silent ausgeführt
- **Log-Pfad**: Neu unter `C:\Windows\Logs\VID\vid-apps-install.log`

---

## v1.4 – 2026-03-30

### Fixes
- **`11-xenserver/variables.pkr.hcl`**: Semikolons durch HCL-konforme Multi-Line-Blöcke ersetzt (behebt `Invalid character ";"` Fehler bei `packer fmt`)

### Tooling
- **`validate.sh`**: `packer init` wird jetzt automatisch pro Template vor `packer validate` ausgeführt – kein manueller Init-Schritt mehr nötig
- **`validate.sh`**: Hypervisor-Trennung eingeführt – XenServer-Templates erhalten eigene Dummy-Variablen ohne vSphere-var-files (verhindert Warning-Flut)
- **`validate.sh`**: `11-xenserver` vorerst aus TARGETS auskommentiert (WIP – XenServer-Plugin-Setup ausstehend)

---

## v1.3 – 2026-03-03

### Fixes
- **Packer build**: Build-Befehl zeigt jetzt auf Verzeichnis (`./windows/desktop/11/`) statt auf einzelne Datei – dadurch wird `variables.pkr.hcl` korrekt geladen (behebt "Unsupported attribute"-Fehler)
- **apps-manifest.json**: `file`-Provisioner hochlädt die Datei auf die Build-VM vor der App-Installation (behebt "Manifest not found"-Fehler)
- **SMB-Username**: Hinweis auf doppelten Backslash in HCL-Strings (`DOMAIN\\user`)

### Neue Features
- **`domain_join_computer_name`**: Neue Variable für den AD-Computer-Account-Namen; verhindert zufällig generierten Namen (z.B. `adminst-4svgp00`); leer lassen = Windows-generierter Name
- **VDA-Installer**: `vid_vda_installer` auf `VDAWorkstationSetup_2511.exe` aktualisiert; lokaler Temp-Pfad in `windows-citrix-vda.ps1` dynamisch

### Dokumentation
- README.md komplett überarbeitet: korrektes Layer-Modell, alle Build-Targets, SMB-Share-Struktur, Domain-Join-Konfiguration, Hardware-Einstellungen, erweiterte Troubleshooting-Tabelle

---

## v1.2 – 2026-03-02

### Neue Features
- **`w11-full` Build-Target**: Neues Target das alles außer Citrix baut (OS, Updates, Domain-Join, Apps) – nützlich für Tests ohne Citrix-Lizenz; gesteuert über `build_include_citrix = false`
- **`w11-base` Build-Target**: Nur Layer 5+6 (OS + VMware Tools + Updates); schnellster Infrastrukturtest; gesteuert über `build_layer5_only = true`
- **Active Directory Domain-Join**: VM tritt AD-Domain bei nach Windows Updates und vor VDA-Installation; Credentials aus `build.pkrvars.hcl`; neue Variablen: `domain_join_enabled`, `domain_name`, `domain_join_username`, `domain_join_password`, `domain_join_ou`
- **DEX Agent deaktiviert**: `windows-dex-agent.ps1` Provisioner auskommentiert – kommt am Ende des Projekts (Layer 8)
- **`build.sh`** im Repository-Root als zentraler Einstiegspunkt mit Voraussetzungs-Check (packer, xorriso, Konfigurationsdateien)

### Applikationen
- `apps-manifest.json`: IT Tools Gruppe – Sysinternals und WinSCP deaktiviert (`"enabled": false`)

---

## v1.1 – 2026-03-01

### Neue Features
- **XenServer-Support**: Zweiter Build-Pfad für Citrix Hypervisor / XenServer (`windows/desktop/11-xenserver/`)
- **App-Installation Framework**: `windows-apps-install.ps1` mit `apps-manifest.json` (Winget primär, Chocolatey Fallback)
- **VID-Data SMB-Repository**: Zentraler Share für VDA-Installer, DEX-Agents, Treiber und App-Installer; standardisierte Ordnerstruktur

---

## v1.0 – 2026-02-28

### Initial Release
- Packer-Pipeline für Windows 11 + Citrix VDA auf VMware vSphere
- `windows.pkr.hcl` mit dynamischen Provisioner-Blöcken (VID Layer 5–7)
- `windows-prepare.ps1` – OS-Baseline (Härtung, WinRM, RDP)
- `windows-citrix-vda.ps1` – Citrix VDA Silent-Installation vom SMB-Share (Option A) oder vSphere-Datastore (Option B)
- `windows-citrix-optimize.ps1` – Citrix VDI-Optimierungen
- `windows-citrix-mcs-prep.ps1` – MCS Master Image Seal (kein Sysprep)
- `autounattend.pkrtpl.hcl` – Vollautomatische Windows 11 Installation
- README, Architekturkonzept v1.0
