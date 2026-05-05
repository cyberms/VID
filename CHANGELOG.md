# Release History

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
