# Release History

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
