# VID – Vendor Independence Day

![Packer](https://img.shields.io/badge/HashiCorp%20Packer-1.9%2B-blue?style=for-the-badge&logo=packer&logoColor=white)
![Windows 11](https://img.shields.io/badge/Windows%2011-Enterprise%20Eval-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Citrix](https://img.shields.io/badge/Citrix-MCS-green?style=for-the-badge)

Automatisierte Erstellung von Windows 11 Master-Images für Citrix Virtual Apps and Desktops (CVAD) mit HashiCorp Packer und Citrix Machine Creation Services (MCS) auf VMware vSphere.

## Übersicht

Das VID-Projekt implementiert eine 8-Schichten-Architektur für eine herstellerunabhängige End-User-Computing-Umgebung. Jede Schicht kann unabhängig von den anderen ausgetauscht werden.

| Layer | Inhalt | Packer-Schritt |
|-------|--------|----------------|
| 5 | Windows 11 Enterprise – OS-Basis, VMware Tools, Windows Updates | w11-base |
| 6 | Hypervisor-Treiber (VMware Tools / Citrix VM Tools) | w11-base |
| 7a | Citrix Virtual Delivery Agent (VDA) | w11-vda |
| 7b | Citrix-Optimierungen | w11-vda |
| 7c | Applikationen (apps-manifest.json) | w11-full / w11-vda |
| 7d | Active Directory Domain-Join (optional) | w11-full / w11-vda |
| 8 | DEX Agent & Monitoring (ControlUp / uberagent) | später |
| MCS | Machine Creation Services Seal | w11-vda |

Der Build-Prozess erstellt eine fertige Master-VM in vSphere, die direkt von Citrix MCS für das Deployment verwendet wird (`common_template_conversion = false`).

## Voraussetzungen

### Build-System (Linux/Ubuntu)

```bash
# Packer installieren
sudo apt update && sudo apt install -y packer

# Pflichtpaket: xorriso (für virtuelle CD-ISO-Erstellung)
sudo apt install -y xorriso git
```

### Packer-Plugins

Die Plugins werden beim ersten Aufruf von `packer init` automatisch heruntergeladen:

- [packer-plugin-vsphere](https://developer.hashicorp.com/packer/plugins/builders/vsphere/vsphere-iso) 1.2.0+
- [packer-plugin-windows-update](https://github.com/rgl/packer-plugin-windows-update) 0.14.3+
- [packer-plugin-git](https://github.com/ethanmdavidson/packer-plugin-git) 0.4.2+

### vSphere / Infrastruktur

- vCenter Server mit API-Zugang
- Datastore mit ausreichend Speicherplatz (~60 GB pro Build)
- Windows 11 ISO auf dem Datastore
- VMware Tools ISO auf dem Datastore
- Netzwerk mit DHCP

### VID-Data SMB-Share

Alle Build-Artefakte werden über einen zentralen SMB-Share bereitgestellt:

```
\\<server>\VID-Data\
  Citrix\VDA\          ← Citrix VDA Installer (z.B. VDAWorkstationSetup_2511.exe)
  citrix\optimize\     ← Optionale Custom-Optimierungsskripte
  microsoft\avd\       ← AVD Agent (Phase 3)
  microsoft\fslogix\   ← FSLogix (Phase 2+)
  dex\controlup\       ← ControlUp Agent (Layer 8 – später)
  dex\uberagent\       ← uberagent (Layer 8 – später)
  drivers\vmware\      ← Zusätzliche VMware-Treiber
  apps\                ← Business-App-Installer (Layer 7c)
```

Der Build-Account benötigt Leserechte auf dem Share. Die VM muss **nicht** in der Domain sein – Credentials werden explizit übergeben.

## Konfiguration

### Schritt 1 – Konfigurationsdateien anlegen

Die sensitiven Konfigurationsdateien sind **nicht** im Repository enthalten (`.gitignore`). Erstelle sie aus den Beispieldateien:

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

### Schritt 3 – ISO-Quellen und SMB-Share konfigurieren

Bearbeite `packer/config/sources.pkrvars.hcl`:

```hcl
# Windows 11 ISO
common_iso_datastore = "datastore1"
iso_path             = "iso"
iso_file             = "Win11_Enterprise_Eval.iso"
iso_checksum_type    = "sha256"
iso_checksum_value   = "CHECKSUM_DES_ISO"

# VMware Tools ISO
vmtools_iso_datastore = ""          # leer = ESXi host-local
vmtools_iso_path      = "/vmimages/tools-isoimages/windows.iso"

# VID-Data SMB-Share
vid_smb_server    = "fileserver.example.com"
vid_smb_share     = "VID-Data"
vid_smb_username  = "DOMAIN\\svc-packer"
vid_smb_password  = "DEIN_PASSWORT"
vid_vda_installer = "VDAWorkstationSetup_2511.exe"
```

> **Tipp:** SHA256-Prüfsumme ermitteln mit `sha256sum Win11.iso` (Linux) oder `Get-FileHash Win11.iso -Algorithm SHA256` (PowerShell).

> **Hinweis:** Backslashes in HCL-Strings müssen verdoppelt werden: `DOMAIN\\user` statt `DOMAIN\user`.

### Schritt 4 – Build-Account und Domain-Join konfigurieren

Bearbeite `packer/config/build.pkrvars.hcl`:

```hcl
# Lokaler Administrator während des Builds
build_username = "adminst"
build_password = "DEIN_PASSWORT"

# Active Directory Domain-Join (vor VDA-Installation)
domain_join_enabled       = true
domain_name               = "sav-kb.de"
domain_join_username      = "svc-packer@sav-kb.de"
domain_join_password      = "DEIN_PASSWORT"
domain_join_ou            = "OU=GoldenImage,OU=VDI,OU=Clients,DC=sav-kb,DC=de"
domain_join_computer_name = "VID-W11-BUILD"   # leer = Windows-generierter Name
```

> **Hinweis:** `domain_join_enabled = false` deaktiviert den Domain-Join vollständig.

### Schritt 5 – VM-Hardware anpassen (optional)

Die VM-Größe für den Build-Prozess wird in `packer/windows/desktop/11/windows.auto.pkrvars.hcl` definiert:

```hcl
vm_cpu_count  = 2       # vCPU Sockets
vm_cpu_cores  = 1       # Kerne pro Socket → gesamt 2 vCPU
vm_mem_size   = 4096    # RAM in MB → 4 GB
vm_disk_size  = 102400  # Disk in MB → 100 GB
```

> **Hinweis:** Die Dimensionierung des Master-Images hat keinen Einfluss auf die späteren VDI-Desktops – die Größe wird in MCS am Katalog festgelegt.

## Applikationen konfigurieren

Welche Apps installiert werden, steuert `packer/scripts/windows/apps-manifest.json`. Die Datei wird automatisch vor der Installation auf die Build-VM hochgeladen.

```json
{
  "groups": [
    {
      "group": "Productivity",
      "enabled": true,
      "apps": [
        { "name": "7-Zip", "enabled": true, "winget": "7zip.7zip", "chocolatey": "7zip" },
        { "name": "Adobe Reader", "enabled": true, "winget": "Adobe.Acrobat.Reader.64-bit" }
      ]
    }
  ]
}
```

Primär-Installer ist **Winget**, Fallback ist **Chocolatey**. Apps mit `"enabled": false` werden übersprungen.

## Build starten

```bash
# Vom Repository-Root ausführen:
./build.sh w11-base    # Schnellster Test: nur OS + VMware Tools + Updates
./build.sh w11-full    # Alles außer Citrix: OS, Updates, Domain-Join, Apps
./build.sh w11-vda     # Vollständiges Master-Image inkl. Citrix VDA + MCS-Seal
```

### Build-Targets im Überblick

| Target | Layer | Inhalt | Verwendung |
|--------|-------|--------|------------|
| `w11-base` | 5+6 | OS + VMware Tools + Updates | Schneller Infrastrukturtest |
| `w11-full` | 5+6+7c+7d | Alles außer Citrix VDA | Test ohne Citrix-Lizenz |
| `w11-vda` | 5–8 | Vollständiges Master-Image | Produktion / MCS |

### Was passiert beim Build (`w11-vda`):

1. **Windows 11 Installation** – Vollautomatisch via `autounattend.xml`
2. **VMware Tools** – Silent-Installation aus ISO
3. **WinRM-Initialisierung** – Packer-Verbindung wird aufgebaut
4. **OS-Baseline** – `windows-prepare.ps1` (Härtung, Grundkonfiguration)
5. **Windows Updates** – Alle verfügbaren Updates (Pre-VDA)
6. **Domain-Join** – VM tritt der AD-Domain bei (wenn `domain_join_enabled = true`)
7. **Neustart** – Nach Domain-Join
8. **App-Installation** – `apps-manifest.json` (Winget / Chocolatey)
9. **Citrix VDA** – Silent-Installation vom SMB-Share
10. **Neustart** – Nach VDA-Installation
11. **Post-VDA Updates** – Windows Updates nach VDA
12. **Citrix-Optimierungen** – `windows-citrix-optimize.ps1`
13. **MCS-Seal** – `windows-citrix-mcs-prep.ps1` (Cleanup, kein Sysprep)
14. **VM wird in vSphere gespeichert** – Direkt als Master-Image verwendbar

> **Hinweis:** Der Build dauert typischerweise **60–90 Minuten**, abhängig von der Anzahl der Windows Updates.

> **MCS-Hinweis:** Sysprep ist **nicht** erforderlich. MCS übernimmt Machine Identity (SID, Hostname, Domain-Join) automatisch beim Provisioning.

### Debug-Modus

```bash
PACKER_LOG=1 PACKER_LOG_PATH=packer-debug.log ./build.sh w11-vda
```

## Verzeichnisstruktur

```
.
├── build.sh                             # Einstiegspunkt (vom Repo-Root ausführen)
├── packer/
│   ├── create_templates.sh              # Internes Build-Skript
│   ├── config/
│   │   ├── common.pkrvars.hcl           # Allgemeine Einstellungen (Timeouts, MCS-Modus)
│   │   ├── vsphere.pkrvars.hcl          # vCenter-Zugangsdaten (nicht im Repo)
│   │   ├── build.pkrvars.hcl            # Build-Account + Domain-Join (nicht im Repo)
│   │   ├── sources.pkrvars.hcl          # ISO-Pfade + SMB-Share (nicht im Repo)
│   │   ├── vsphere.pkrvars.hcl.example
│   │   ├── build.pkrvars.hcl.example
│   │   └── sources.pkrvars.hcl.example
│   ├── scripts/windows/
│   │   ├── windows-prepare.ps1          # OS-Baseline (Layer 5)
│   │   ├── windows-domain-join.ps1      # AD Domain-Join (Layer 5→7)
│   │   ├── windows-apps-install.ps1     # App-Installation via Manifest (Layer 7c)
│   │   ├── apps-manifest.json           # App-Konfiguration (Winget / Chocolatey)
│   │   ├── windows-citrix-vda.ps1       # Citrix VDA Installation (Layer 7a)
│   │   ├── windows-citrix-optimize.ps1  # Citrix-Optimierungen (Layer 7b)
│   │   └── windows-citrix-mcs-prep.ps1  # MCS-Vorbereitung / Seal
│   └── windows/desktop/11/
│       ├── windows.pkr.hcl              # Haupt-Packer-Template
│       ├── variables.pkr.hcl            # Variablen-Definitionen
│       ├── windows.auto.pkrvars.hcl     # VM-Hardware-Einstellungen
│       └── data/
│           └── autounattend.pkrtpl.hcl  # Windows-Antwortdatei
├── citrix-mcs/
│   ├── deploy-citrix-mcs.ps1            # MCS-Deployment (Windows-Host)
│   └── update-image.ps1                 # Image-Update in Citrix DaaS
└── Vendor-Independence-Day-Architekturkonzept-v1.0.md
```

## Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| `xorriso` nicht gefunden | Paket fehlt | `sudo apt install -y xorriso` |
| `Invalid escape sequence` in HCL | Einfacher Backslash in String | `DOMAIN\\user` statt `DOMAIN\user` |
| `Unsupported attribute` beim Build | Build-VM hat alten Git-Stand | `git pull` auf der Build-VM |
| `apps-manifest.json not found` | Datei nicht auf VM hochgeladen | Liegt an fehlendem `file`-Provisioner (bereits gefixt) |
| `timeout waiting for IP address` | VMware Tools fehlen oder ISO-Pfad falsch | `vmtools_iso_path` in `sources.pkrvars.hcl` prüfen |
| Build hängt bei Windows Updates | Normal – Updates dauern 15–45 Min | Warten, ggf. `common_ip_wait_timeout` erhöhen |
| Domain-Join schlägt fehl | Computer-Account existiert bereits | Alten Account im AD löschen vor dem nächsten Build |

## Sicherheit

- **Passwörter** werden niemals committed – alle sensitiven `.pkrvars.hcl` sind in `.gitignore`
- Für CI/CD-Systeme: Umgebungsvariablen mit `PKR_VAR_`-Prefix verwenden (z.B. `PKR_VAR_build_password`)
- Der Build-Account (`adminst`) wird nur während des Build-Prozesses benötigt
- SMB-Zugang erfolgt mit expliziten Credentials – kein Domain-Join der Build-VM erforderlich

## Dokumentation

- [Vendor-Independence-Day-Architekturkonzept-v1.0.md](Vendor-Independence-Day-Architekturkonzept-v1.0.md)
