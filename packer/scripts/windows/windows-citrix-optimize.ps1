<#
.SYNOPSIS
    VID Layer 7b – Citrix-spezifische VDI Optimierungen

.DESCRIPTION
    Wendet Citrix CVAD-spezifische Optimierungen an.
    Läuft NACH windows-vdi-optimize.ps1 (generische Optimierungen).

    Inhalt:
      [1]  Windows Defender Exclusions – Citrix VDA Verzeichnisse
      [2]  Citrix Registry Tweaks – CtxHook, EDT/UDT, HDX, DWM

    Nicht enthalten (bereits in windows-vdi-optimize.ps1):
      Power Plan, Services, Scheduled Tasks, Telemetrie, OneDrive, AppX,
      Event Logs, Netzwerk, Storage, Visual/UI, Terminal Services, ...

.NOTES
    VID Layer  : 7b – Citrix-specific Optimizations
    Broker     : citrix-mcs, citrix-pvs
    Maintainer : VID-Team
    Basis      : Citrix CTX216252, Citrix Optimizer, Citrix Automation Handbook 2601
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-citrix-optimize.log"
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
Write-VIDLog "VID Layer 7b – Citrix-spezifische Optimierungen"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "═══════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# [1] Windows Defender Exclusions für Citrix VDA
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [1] Windows Defender Exclusions (Citrix) ---"

$defenderExclusions = @(
    "$env:ProgramFiles\Citrix",
    "$env:ProgramData\Citrix",
    "C:\Windows\Temp\Citrix*"
)
foreach ($exclusion in $defenderExclusions) {
    Add-MpPreference -ExclusionPath $exclusion -ErrorAction SilentlyContinue
    Write-VIDLog "  Defender Exclusion: $exclusion"
}

# ─────────────────────────────────────────────────────────────────────────────
# [2] Citrix-spezifische Registry Tweaks
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [2] Citrix Registry Tweaks ---"

# VDA Hook / AppInit DLLs (Standardwert explizit setzen)
Set-RegistryValue "HKLM:\SOFTWARE\Citrix\CtxHook\AppInit_DLLs\SwitchHook" "ExcludedImageNames" "" -Type "String"

# EDT (Enlightened Data Transport) / UDT-Protokoll aktivieren
# Ermöglicht UDP-basierte HDX-Übertragung (geringere Latenz, bessere Bandbreitennutzung)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Citrix\ICA Client\Engine\Lockdown Profiles\All Regions\Lockdown\Network\UDT" `
    "UDTProtocol" "true" -Type "String"

# Desktop Composition für flüssige Benutzeroberfläche in ICA-Sessions
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" "DisallowFlip3d" 0

# ─────────────────────────────────────────────────────────────────────────────
# VID Registry – Sentinel
# ─────────────────────────────────────────────────────────────────────────────

$sentinelKey = "HKLM:\SOFTWARE\VendorIndependenceDay\Optimization"
if (-not (Test-Path $sentinelKey)) { New-Item -Path $sentinelKey -Force | Out-Null }
Set-ItemProperty -Path $sentinelKey -Name "CitrixOptimizeApplied"   -Value "Applied"
Set-ItemProperty -Path $sentinelKey -Name "CitrixOptimizeTimestamp" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – Citrix-Optimierungen abgeschlossen."
Write-VIDLog "Log: $logFile"
Write-VIDLog "═══════════════════════════════════════════════"
