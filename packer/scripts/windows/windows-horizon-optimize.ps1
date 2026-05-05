<#
.SYNOPSIS
    VID Layer 7b – Horizon-spezifische VDI Optimierungen

.DESCRIPTION
    Wendet VMware/Broadcom Horizon-spezifische Optimierungen an.
    Läuft NACH windows-vdi-optimize.ps1 (generische Optimierungen).

    Inhalt:
      [1]  Horizon-spezifische Registry Tweaks (Blast Extreme, USB, DPI)
      [2]  VMware OSOT (OS Optimization Tool) – Referenz / optionaler Aufruf
      [3]  Desktop-Shortcuts bereinigen

    Nicht enthalten (bereits in windows-vdi-optimize.ps1):
      Power Plan, Services (SysMain, WSearch), Scheduled Tasks, Telemetrie,
      OneDrive, AppX, Event Logs, Netzwerk, Storage, Visual/UI, ...

    Empfehlung: VMware OS Optimization Tool (OSOT) als primäres Werkzeug
      https://github.com/vmware/osot
      VMwareOSOptimizationTool.exe -o -t Win11_2x

.NOTES
    VID Layer  : 7b – Horizon-specific Optimizations
    Broker     : horizon
    Maintainer : VID-Team
    Status     : STUB – Tweaks vor Produktiveinsatz mit Horizon-Version abgleichen!
    Basis      : VMware/Broadcom Horizon Optimization Guide, OSOT Templates
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-horizon-optimize.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force | Out-Null
        Write-VIDLog "  REG SET: $Path\$Name = $Value"
    }
    catch { Write-VIDLog "  REG FAIL: $Path\$Name - $($_.Exception.Message)" "WARN" }
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – Horizon-spezifische Optimierungen"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "═══════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# [1] Horizon / Blast Extreme Registry Tweaks
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [1] Horizon Registry Tweaks ---"

# Blast Extreme Encoder: H.264-Encodierung bevorzugen (bessere Leistung ohne vGPU)
# Wert 0 = Automatisch (Standard), 1 = H.264, 2 = HEVC (nur mit GPU)
# TODO: Wert nach Tests mit der jeweiligen Horizon-Version und Hardware validieren
Set-RegistryValue "HKLM:\SOFTWARE\VMware, Inc.\VMware Blast\Config" "EncoderMaxQuality" 85 -Type "DWord"

# DPI-Synchronisierung: Client-DPI auf die Session übertragen (Schärfe auf HiDPI-Displays)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\VMware, Inc.\VMware VDM\Agent\Configuration" "AllowDisplayScaling" 1

# ─────────────────────────────────────────────────────────────────────────────
# [2] VMware OS Optimization Tool (OSOT) – optional, empfohlen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [2] OSOT (optional) ---"
# OSOT kann als Kommandozeilen-Tool im Packer-Build ausgeführt werden:
#   VMwareOSOptimizationTool.exe -o -t Win11_2x
# Template-Dateien: https://github.com/vmware/osot
# Wenn OSOT auf dem SMB-Share liegt, hier einkommentieren:
#
# $osotPath = "C:\Windows\Temp\VMwareOSOptimizationTool.exe"
# if (Test-Path $osotPath) {
#     Write-VIDLog "  Starte OSOT..."
#     $p = Start-Process -FilePath $osotPath -ArgumentList "-o -t Win11_2x" -Wait -PassThru -NoNewWindow
#     Write-VIDLog "  OSOT Exit-Code: $($p.ExitCode)"
# } else {
#     Write-VIDLog "  OSOT nicht gefunden – übersprungen." "WARN"
# }

Write-VIDLog "  OSOT: deaktiviert (einkommentieren wenn OSOT auf SMB-Share liegt)"

# ─────────────────────────────────────────────────────────────────────────────
# [3] Desktop-Shortcuts bereinigen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [3] Desktop Cleanup ---"
$shortcuts = @(
    "$env:PUBLIC\Desktop\Microsoft Edge.lnk"
)
foreach ($s in $shortcuts) {
    if (Test-Path $s) {
        Remove-Item -Path $s -Force -ErrorAction SilentlyContinue
        Write-VIDLog "  Shortcut entfernt: $s"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# VID Registry – Sentinel
# ─────────────────────────────────────────────────────────────────────────────

$sentinelKey = "HKLM:\SOFTWARE\VendorIndependenceDay\Optimization"
if (-not (Test-Path $sentinelKey)) { New-Item -Path $sentinelKey -Force | Out-Null }
Set-ItemProperty -Path $sentinelKey -Name "HorizonOptimizeApplied"   -Value "Applied"
Set-ItemProperty -Path $sentinelKey -Name "HorizonOptimizeTimestamp" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – Horizon-Optimierungen abgeschlossen."
Write-VIDLog "Log: $logFile"
Write-VIDLog "═══════════════════════════════════════════════"
