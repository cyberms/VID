# VID – Vendor Independence Day

![Packer](https://img.shields.io/badge/HashiCorp%20Packer-1.9%2B-blue?style=for-the-badge&logo=packer&logoColor=white)
![Windows 11](https://img.shields.io/badge/Windows%2011-Enterprise%20Eval-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Citrix](https://img.shields.io/badge/Citrix-MCS-green?style=for-the-badge)

Automatisierte Erstellung von Windows 11 Master-Images für Citrix Virtual Apps and Desktops (CVAD) mit HashiCorp Packer und Citrix Machine Creation Services (MCS) auf VMware vSphere.

## Übersicht

Das VID-Projekt implementiert eine 8-Schichten-Architektur für eine herstellerunabhängige End-User-Computing-Umgebung:

| Layer | Inhalt |
|-------|--------|
| 1 | Windows 11 Enterprise (Basis-OS) |
| 2 | VMware Tools |
| 3 | Windows Updates |
| 4 | Citrix Virtual Delivery Agent (VDA) |
| 5 | Citrix-Optimierungen |
| 6 | DEX Agent & Monitoring |
| 7 | Applikationen |
| 8 | MCS-Vorbereitung (Seal) |

Der Build-Prozess erstellt eine fertige Master-VM in vSphere, die direkt von Citrix MCS für das Deployment verwendet wird (`common_template_conversion = false`).

## Voraussetzungen

### Build-System (Linux/Ubuntu)

```bash
# Packer installieren
sudo apt update && sudo apt install -y packer

# Packer vSphere-Plugin initialisieren (wird automatisch beim ersten Build geladen)
# Pflichtpaket: xorriso (für virtuelle CD-ISO-Erstellung)
sudo apt install -y xorriso git
```

### Packer-Plugins

Die Plugins werden beim ersten Aufruf von `packer init` automatisch heruntergeladen:

- [packer-plugin-vsphere](https://developer.hashicorp.com/packer/plugins/builders/vsphere/vsphere-iso) 1.2.0+
- [packer-plugin-windows-update](https://github.com/rgl/packer-plugin-windows-update) 0.14.3+

### vSphere / Infrastruktur

- vCenter Server mit API-Zugang
- Datastore mit ausreichend Speicherplatz (~60 GB pro Build)
- Windows 11 ISO auf dem Datastore
- VMware Tools ISO auf dem Datastore (empfohlen: `iso/vmwaretools/windows.iso`)
- Netzwerk mit DHCP

## Konfiguration

### Schritt 1 – Konfigurationsdateien anlegen

Die sensitiven Konfigurationsdateien sind **nicht** im Repository enthalten (`.gitignore`). Erstelle sie aus den mitgelieferten Beispieldateien:

```bash
cd packer/config

cp vsphere.pkrvars.hcl.example vsphere.pkrvars.hcl
cp build.pkrvars.hcl.example   build.pkrvars.hcl
cp sources.pkrvars.hcl.example sources.pkrvars.hcl
```

### Schritt 2 – vSphere-Verbindung konfigurieren

Bearbeite `packer/config/vsphere.pkrvars.hcl`:

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

### Schritt 3 – ISO-Quellen konfigurieren

Bearbeite `packer/config/sources.pkrvars.hcl`:

```hcl
common_iso_datastore = "datastore1"
iso_path             = "iso"
iso_file             = "Win11_Enterprise_Eval.iso"
iso_checksum_type    = "sha256"
iso_checksum_value   = "CHECKSUM_DES_ISO"

vmtools_iso_datastore = "datastore1"
vmtools_iso_path      = "iso/vmwaretools/windows.iso"
```

> **Tipp:** SHA256-Prüfsumme ermitteln mit `sha256sum Win11.iso` (Linux) oder `Get-FileHash Win11.iso -Algorithm SHA256` (PowerShell).

### Schritt 4 – Build-Account konfigurieren

Bearbeite `packer/config/build.pkrvars.hcl`:

```hcl
build_username = "adminst"
build_password = "DEIN_PASSWORT"
```

> **Empfehlung für Produktion:** Passwort als Umgebungsvariable setzen statt im Klartext:
> ```bash
> export PKR_VAR_build_password="PASSWORT"
> ```

## Build starten

```bash
cd packer
./create_templates.sh w11-base
```

### Was passiert beim Build:

1. **Windows 11 Installation** – Vollautomatisch via `autounattend.xml`
2. **VMware Tools Installation** – Automatische CD-Erkennung und Stille Installation
3. **Windows Updates** – Alle verfügbaren Updates (außer Preview und Defender-Signaturen)
4. **Provisioner** – `windows-prepare.ps1`, weitere Skripte je nach Konfiguration
5. **MCS-Vorbereitung** – `windows-citrix-mcs-prep.ps1` (Seal)
6. **VM wird in vSphere gespeichert** – Direkt als Master-Image verwendbar

> **Hinweis:** Der Build dauert typischerweise **45–90 Minuten**, abhängig von der Anzahl der Windows Updates.

### Debug-Modus

```bash
cd packer
PACKER_LOG=1 PACKER_LOG_PATH=packer-debug.log ./create_templates.sh w11-base
```

## Verzeichnisstruktur

```
.
├── packer/
│   ├── create_templates.sh          # Build-Startskript
│   ├── config/
│   │   ├── common.pkrvars.hcl       # Allgemeine Einstellungen (Timeouts, MCS-Modus)
│   │   ├── vsphere.pkrvars.hcl      # vCenter-Zugangsdaten (nicht im Repo)
│   │   ├── build.pkrvars.hcl        # Build-Account-Credentials (nicht im Repo)
│   │   ├── sources.pkrvars.hcl      # ISO-Pfade und Checksums (nicht im Repo)
│   │   ├── vsphere.pkrvars.hcl.example
│   │   ├── build.pkrvars.hcl.example
│   │   └── sources.pkrvars.hcl.example
│   ├── scripts/windows/
│   │   ├── windows-vmtools.ps1      # VMware Tools Installation
│   │   ├── windows-prepare.ps1      # Basis-Systemkonfiguration
│   │   ├── windows-citrix-vda.ps1   # Citrix VDA Installation
│   │   ├── windows-citrix-optimize.ps1  # Citrix-Optimierungen
│   │   ├── windows-citrix-mcs-prep.ps1  # MCS-Vorbereitung (Seal)
│   │   ├── windows-apps-install.ps1     # Applikationsinstallation
│   │   ├── windows-dex-agent.ps1        # DEX Agent Installation
│   │   └── apps-manifest.json           # App-Konfiguration
│   └── windows/desktop/11/
│       ├── windows.pkr.hcl          # Haupt-Packer-Template
│       ├── variables.pkr.hcl        # Variablen-Definitionen
│       ├── windows.auto.pkrvars.hcl # VM-Hardware-Einstellungen
│       └── data/
│           └── autounattend.pkrtpl.hcl  # Windows-Antwortdatei
└── Vendor-Independence-Day-Architekturkonzept-v1.0.md
```

## Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| `could not find a supported CD ISO creation command` | `xorriso` fehlt | `sudo apt install -y xorriso` |
| `timeout waiting for IP address` | VMware Tools nicht installiert | ISO-Pfad in `sources.pkrvars.hcl` prüfen |
| WinRM-Verbindung schlägt fehl | Firewall oder falsches Netzwerk | vSphere-Netzwerk und DHCP prüfen |
| Build hängt bei Windows Updates | Normal – Updates können 15–45 Min dauern | Warten, `common_ip_wait_timeout = "60m"` |

## Sicherheit

- **Passwörter** werden niemals committed – alle sensitiven `.pkrvars.hcl` sind in `.gitignore`
- Für die Übergabe an CI/CD-Systeme: Umgebungsvariablen mit `PKR_VAR_`-Prefix verwenden
- Der Build-Account (`adminst`) wird nur während des Build-Prozesses benötigt

## Dokumentation

Weiterführende Architektur- und Implementierungsdetails:

- [Vendor-Independence-Day-Architekturkonzept-v1.0.md](Vendor-Independence-Day-Architekturkonzept-v1.0.md)
