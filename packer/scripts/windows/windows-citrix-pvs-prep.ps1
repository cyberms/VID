<#
.SYNOPSIS
    VID Layer 7f – Citrix Provisioning Services (PVS) Master Image Vorbereitung

.DESCRIPTION
    Bereitet eine Windows 11 VM als Citrix PVS Master Image vor.
    Muss nach dem VDA-Install (Layer 7a) und den Optimierungen (Layer 7b) laufen,
    direkt vor dem PVS Imaging Wizard / Sysprep.

    Ablauf:
      1. Zusätzliche PVS-spezifische Services deaktivieren (Spooler, Fax, WMPNet, ...)
      2. Windows Update auf Manual setzen (PVS streamt – kein Auto-Update im vDisk)
      3. Page File: automatisch managed (PVS Target Device erzeugt keine eigene Disk)
      4. Optionaler PVS Target Device Software-Install (via $PvsInstallerPath)
      5. VID Sentinel setzen

    Voraussetzungen:
      - windows-vdi-optimize.ps1 bereits ausgeführt (Layer 7b)
      - windows-citrix-vda.ps1 bereits ausgeführt (Layer 7a)
      - PVS Target Device Software liegt auf dem SMB-Share (VID_DATA_PATH)
        Dateiname: PVS_Device_x64.exe (oder via Parameter übergeben)

    Danach manuell:
      - Citrix Imaging Wizard ausführen (erstellt vDisk)
      - oder: PVS-Sysprep + vDisk-Seal via PVS Console

.PARAMETER PvsInstallerPath
    Vollständiger Pfad zum PVS Target Device Installer (optional).
    Wird gesetzt, wenn VID_DATA_PATH auf den SMB-Share zeigt.
    Format: \\server\share\citrix\pvs\PVS_Device_x64.exe

.NOTES
    VID Layer  : 7f – Finalize / Platform Prep
    Broker     : Citrix PVS (citrix-pvs)
    Maintainer : VID-Team
    Basis      : xoap windows11-Prepare_For_Citrix_PVS.ps1 + Citrix PVS Best Practices
    Created    : 2026-05-06
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PvsInstallerPath = $env:VID_PVS_INSTALLER_PATH
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-citrix-pvs-prep.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

function Disable-ServiceSafely {
    param([string]$ServiceName, [string]$Reason)
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service  -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Set-Service   -Name $ServiceName -StartupType Disabled
            Write-VIDLog  "  DISABLED service: $ServiceName ($Reason)"
        } else {
            Write-VIDLog  "  SKIP (not found): $ServiceName" "WARN"
        }
    }
    catch { Write-VIDLog "  FAIL disabling $ServiceName: $($_.Exception.Message)" "WARN" }
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7f – Citrix PVS Master Image Prep"
Write-VIDLog "═══════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# [1] PVS-spezifische Service-Deaktivierungen
#     (Ergänzung zu windows-vdi-optimize.ps1 – PVS-relevante Besonderheiten)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [1] PVS-spezifische Services ---"

# Fax + Remote Registry (Sicherheit + nicht benötigt in PVS-Image)
Disable-ServiceSafely "Fax"            "Fax-Dienst (PVS Best Practice)"
Disable-ServiceSafely "RemoteRegistry" "Remote Registry (Security Hardening)"
Disable-ServiceSafely "PhoneSvc"       "Phone Service (Consumer Feature)"
Disable-ServiceSafely "WcnSvc"         "Windows Connect Now (WLAN-Konfiguration)"
Disable-ServiceSafely "StiSvc"         "Windows Image Acquisition (kein Scanner in PVS)"
Disable-ServiceSafely "FrameServer"    "Windows Camera Frame Server"
Disable-ServiceSafely "seclogon"       "Secondary Logon (PVS-Sicherheitsempfehlung)"

# ─────────────────────────────────────────────────────────────────────────────
# [2] Windows Update auf Manual (PVS streamt vDisk – kein Auto-Update möglich)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [2] Windows Update → Manual (PVS) ---"
try {
    Set-Service -Name "wuauserv" -StartupType Manual
    Write-VIDLog "  wuauserv auf Manual gesetzt."
}
catch { Write-VIDLog "  FAIL wuauserv: $($_.Exception.Message)" "WARN" }

# ─────────────────────────────────────────────────────────────────────────────
# [3] Page File – Automatisch managed
#     PVS Target Devices haben keinen persistenten Schreibcache für die OS-Disk,
#     daher sollte der Page File auf system-managed stehen oder deaktiviert werden.
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [3] Page File (PVS: automatisch) ---"
try {
    $cs = Get-WmiObject -Class Win32_ComputerSystem
    $cs.AutomaticManagedPageFile = $true
    $cs.Put() | Out-Null
    Write-VIDLog "  Page File auf automatisch gesetzt (WMI)."
}
catch {
    Write-VIDLog "  WMI Put() fehlgeschlagen – Registry-Fallback." "WARN"
    $mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $mmPath -Name "AutomaticManagedPageFile" -Value 1 -Type DWord -Force
    Write-VIDLog "  Page File registry-fallback gesetzt."
}

# ─────────────────────────────────────────────────────────────────────────────
# [4] PVS Target Device Software installieren (optional)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [4] PVS Target Device Software ---"
if ($PvsInstallerPath -and (Test-Path $PvsInstallerPath)) {
    Write-VIDLog "  Installiere PVS Target Device: $PvsInstallerPath"
    try {
        $proc = Start-Process -FilePath $PvsInstallerPath `
            -ArgumentList "/S /v/qn" `
            -Wait -PassThru
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
            Write-VIDLog "  PVS Target Device installiert (ExitCode: $($proc.ExitCode))."
            if ($proc.ExitCode -eq 3010) {
                Write-VIDLog "  HINWEIS: Reboot erforderlich (ExitCode 3010)." "WARN"
            }
        } else {
            Write-VIDLog "  PVS Target Device: unerwarteter ExitCode $($proc.ExitCode)." "WARN"
        }
    }
    catch {
        Write-VIDLog "  FAIL PVS Target Device Install: $($_.Exception.Message)" "WARN"
    }
} elseif ($PvsInstallerPath) {
    Write-VIDLog "  PVS Installer Pfad gesetzt, aber Datei nicht gefunden: $PvsInstallerPath" "WARN"
    Write-VIDLog "  SMB-Share gemountet? VID_DATA_PATH korrekt?" "WARN"
} else {
    Write-VIDLog "  Kein PVS Installer angegeben – übersprungen."
    Write-VIDLog "  Hinweis: Installer kann nachträglich manuell ausgeführt werden:"
    Write-VIDLog "    \\\\<server>\\vid-data\\citrix\\pvs\\PVS_Device_x64.exe /S /v/qn"
}

# ─────────────────────────────────────────────────────────────────────────────
# [5] Disk Defrag deaktivieren (PVS streamt – Defrag auf vDisk nutzlos und schädlich)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [5] Scheduled Defrag deaktivieren ---"
try {
    $task = Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" -ErrorAction SilentlyContinue
    if ($task) {
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" | Out-Null
        Write-VIDLog "  ScheduledDefrag deaktiviert."
    }
}
catch { Write-VIDLog "  Defrag Task konnte nicht deaktiviert werden: $($_.Exception.Message)" "WARN" }

# ─────────────────────────────────────────────────────────────────────────────
# VID Sentinel
# ─────────────────────────────────────────────────────────────────────────────

$sentinelKey = "HKLM:\SOFTWARE\VendorIndependenceDay\Provisioning"
New-Item -Path $sentinelKey -Force | Out-Null
Set-ItemProperty -Path $sentinelKey -Name "PVSPrepApplied"   -Value "Applied"
Set-ItemProperty -Path $sentinelKey -Name "PVSPrepTimestamp" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7f – Citrix PVS Prep abgeschlossen."
Write-VIDLog ""
Write-VIDLog "NÄCHSTE SCHRITTE (manuell):"
Write-VIDLog "  1. Citrix PVS Imaging Wizard starten"
Write-VIDLog "  2. vDisk erstellen / aktualisieren"
Write-VIDLog "  3. vDisk auf 'Standard Image' setzen und sealem"
Write-VIDLog "Log: $logFile"
Write-VIDLog "═══════════════════════════════════════════════"
