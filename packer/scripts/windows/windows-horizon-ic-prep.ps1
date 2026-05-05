<#
.SYNOPSIS
    VID Layer 7 Finalize – Horizon Instant Clone Master Image Preparation

.DESCRIPTION
    Bereitet das Golden Image für Horizon Instant Clone vor.
    Äquivalent zu windows-citrix-mcs-prep.ps1 für Citrix MCS.

    Instant Clone (IC) klont VMs aus einem laufenden Parent (Quiesce + Fork).
    Das Master Image muss korrekt vorbereitet sein damit IC-VMs sauber starten.

    Wichtig:
      - Kein Sysprep! IC erstellt pro VM eigene Identität.
      - Horizon Agent muss installiert und lizenziert sein.
      - Pagefile-Einstellungen: C:\ (Temp-Disk nicht für IC geeignet)

    Referenz:
      https://docs.vmware.com/en/VMware-Horizon/2312/horizon-virtual-desktops/GUID-IC-overview.html

.NOTES
    VID Layer  : 7 – Finalize
    Broker     : VMware / Broadcom Horizon (Instant Clone)
    Maintainer : VID-Team
    Status     : STUB – vor Produktiveinsatz validieren!
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-horizon-ic-prep.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7 Finalize – Horizon IC-Prep"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "═══════════════════════════════════════════════"

# ── Pagefile: C:\ (Instant Clone braucht keinen D:) ──────────────────────────
Write-VIDLog "Pagefile auf C:\ konfigurieren..."
$cs = Get-WmiObject -Class Win32_ComputerSystem
$cs.AutomaticManagedPagefile = $false
$cs.Put() | Out-Null

Get-WmiObject Win32_PageFileSetting | Remove-WmiObject
New-Object -TypeName System.Management.ManagementObject(
    "Win32_PageFileSetting.Name='C:\\pagefile.sys'"
) | Out-Null
Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
    Name        = "C:\pagefile.sys"
    InitialSize = 0
    MaximumSize = 0
} | Out-Null
Write-VIDLog "Pagefile: System-managed auf C:\."

# ── ClearPageFileAtShutdown = 1 (Sicherheit bei IC) ──────────────────────────
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
                 -Name "ClearPageFileAtShutdown" -Value 1 -Type DWord
Write-VIDLog "ClearPageFileAtShutdown = 1 gesetzt."

# ── Event-Logs leeren ─────────────────────────────────────────────────────────
Write-VIDLog "Event-Logs leeren..."
Get-EventLog -LogName * -ErrorAction SilentlyContinue | ForEach-Object {
    Clear-EventLog -LogName $_.Log -ErrorAction SilentlyContinue
}

# ── Temp-Dateien bereinigen ───────────────────────────────────────────────────
Write-VIDLog "Temp-Dateien bereinigen..."
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# ── VID Registry: IC-Prep dokumentieren ──────────────────────────────────────
$key = "HKLM:\SOFTWARE\VendorIndependenceDay\Build"
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name "BrokerType"       -Value "horizon"
Set-ItemProperty -Path $key -Name "PrepType"         -Value "InstantClone"
Set-ItemProperty -Path $key -Name "PrepDateTime"     -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-VIDLog "Horizon IC-Prep abgeschlossen. Image bereit für Instant Clone Snapshot."
Write-VIDLog "Nächster Schritt: Snapshot des laufenden Masters in Horizon Console."
