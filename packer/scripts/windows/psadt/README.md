# VID PSADT Packages – Layer 7 Applikationen

Applikationspakete für VID (Vendor Independence Day) basierend auf dem
[XOAP PSADT Framework Template](https://github.com/xoap-io/xoap-psadt-framework-template) (MIT License)
und [PSAppDeployToolkit](https://psappdeploytoolkit.com) v3.9.2.

---

## Verzeichnisstruktur

```
psadt/
├── _framework/                     ← PSADT 3.9.2 Framework (aus xoap-Template)
│   ├── AppDeployToolkit/
│   │   ├── AppDeployToolkitMain.ps1        ← PSADT Core (nicht anfassen)
│   │   ├── AppDeployToolkitConfig.xml      ← Konfiguration
│   │   ├── AppDeployToolkitExtensions.ps1  ← VID-Erweiterungen (Register/Unregister)
│   │   └── ...
│   ├── Deploy-Application.exe      ← EXE-Wrapper (optional)
│   └── ServiceUI.exe               ← UI-Interaktion (optional)
│
├── _template/                      ← Vorlage für neue Pakete
│   ├── Deploy-Application.ps1      ← Kopieren und anpassen
│   └── Files/                      ← Installer-Dateien (nicht in Git)
│
└── packages/                       ← Fertige App-Pakete
    ├── 7-Zip/
    │   └── 24.08.0/
    │       ├── Deploy-Application.ps1
    │       └── Files/              ← 7z2408-x64.msi (nicht in Git, vom SMB-Share)
    └── AdobeReader/
        └── 24.5.0/
            ├── Deploy-Application.ps1
            └── Files/              ← AcroRdrDC*.exe (nicht in Git, vom SMB-Share)
```

---

## Deployment auf den SMB-Share

Die Pakete werden mit dem `_framework/` zusammengeführt und auf den VID-Data SMB-Share
kopiert. Das erledigt `windows-apps-install.ps1` automatisch beim Packer-Build.

Manuelle Struktur auf dem Share:
```
\\DC01\VID-Data\apps\
├── 7-Zip\24.08.0\
│   ├── Deploy-Application.ps1
│   ├── Deploy-Application.exe
│   ├── ServiceUI.exe
│   ├── AppDeployToolkit\        ← aus _framework\ kopiert
│   └── Files\
│       └── 7z2408-x64.msi      ← manuell ablegen
└── AdobeReader\24.5.0\
    ├── Deploy-Application.ps1
    ├── AppDeployToolkit\
    └── Files\
        └── AcroRdrDC*.exe
```

---

## Neues Paket erstellen

```powershell
# 1. Template kopieren
$appName    = 'MeineApp'
$appVersion = '1.0.0'
$dest = "packages\$appName\$appVersion"
Copy-Item -Path '_template' -Destination $dest -Recurse

# 2. Deploy-Application.ps1 anpassen
#    → $appVendor, $appName, $appVersion, $PackageName befüllen
#    → Install-/Uninstall-Logik implementieren

# 3. Installer-Datei in Files\ legen
#    → Datei von Hersteller-Website laden und SHA256 prüfen

# 4. Auf SMB-Share deployen
#    → Automatisch via windows-apps-install.ps1 beim Packer-Build
#    → Oder manuell: Paket + AppDeployToolkit\ auf Share kopieren
```

---

## Aufruf (Silent – Packer-Build)

```powershell
powershell.exe -ExecutionPolicy Bypass -NonInteractive `
    -File ".\Deploy-Application.ps1" `
    -DeploymentType Install `
    -DeployMode Silent
```

---

## VID-Registry

Jede erfolgreiche Installation schreibt Metadaten nach:
```
HKLM:\SOFTWARE\VendorIndependenceDay\InstalledApps\<PackageName>\
    IsInstalled          = 1
    AppName              = "7-Zip"
    AppVersion           = "24.08.0"
    InstallationDateTime = "..."
    InstallationSource   = "\\DC01\VID-Data\apps\7-Zip\24.08.0"
    LogFile              = "C:\Windows\Logs\Software\7-Zip_Install.log"
```

---

## Versionskonvention

| Feld        | Format               | Beispiel              |
|-------------|----------------------|-----------------------|
| PackageName | `Vendor_App_Version` | `7-Zip_7-Zip_24.08.0` |
| Version     | Semantic Versioning  | `24.08.0`             |
| Ordner      | `<AppName>/<Version>`| `7-Zip/24.08.0/`      |
