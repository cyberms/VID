<#
.SYNOPSIS
    VID Layer 7b – VMware / Broadcom Horizon VDI Optimierungen

.DESCRIPTION
    Wendet Horizon-spezifische VDI-Optimierungen an.
    Äquivalent zu windows-citrix-optimize.ps1 für Citrix.

    Empfohlener Ansatz: VMware OS Optimization Tool (OSOT)
      https://flings.vmware.com/vmware-os-optimization-tool
    Alternativ: Broadcom Horizon Optimization Guide manuell umsetzen

    Optimierungen (Beispiele):
      - Windows Update Service → Disabled (Image-Management übernimmt Patches)
      - Windows Defender Real-Time Protection → Policy-basiert (AV via Horizon)
      - Superfetch / SysMain → Disabled (VDI-Performance)
      - Windows Tips / Consumer Features → Disabled
      - OneDrive → Disabled (FSLogix übernimmt Profile)

.NOTES
    VID Layer  : 7b – Broker Optimizations
    Broker     : VMware / Broadcom Horizon
    Maintainer : VID-Team
    Status     : STUB – Optimierungen vor Produktiveinsatz validieren!
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

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – Horizon VDI Optimierungen"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "═══════════════════════════════════════════════"

# ── SysMain (Superfetch) deaktivieren ─────────────────────────────────────────
Write-VIDLog "SysMain (Superfetch) deaktivieren..."
Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
Set-Service  -Name "SysMain" -StartupType Disabled

# ── Windows Update Service für Image-Management steuern ───────────────────────
# Im Golden Image deaktivieren – Patches via OSOT/Packer-Pipeline
Write-VIDLog "Windows Update Service deaktivieren..."
Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
Set-Service  -Name "wuauserv" -StartupType Disabled

# ── OneDrive deinstallieren (FSLogix übernimmt Profile) ───────────────────────
Write-VIDLog "OneDrive entfernen..."
$onedrive = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" -ErrorAction SilentlyContinue
if ($onedrive) {
    $uninstallStr = $onedrive.GetValue("UninstallString")
    if ($uninstallStr) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallStr /uninstall" -Wait -NoNewWindow
        Write-VIDLog "OneDrive deinstalliert."
    }
} else {
    Write-VIDLog "OneDrive nicht gefunden – übersprungen."
}

# ── Desktop-Shortcuts bereinigen ──────────────────────────────────────────────
Write-VIDLog "Desktop-Shortcuts bereinigen..."
$shortcuts = @(
    "$env:PUBLIC\Desktop\Microsoft Edge.lnk"
)
foreach ($s in $shortcuts) {
    Remove-Item -Path $s -Force -ErrorAction SilentlyContinue
}

# ── TODO: VMware OSOT ausführen (optional, empfohlen) ─────────────────────────
# VMware OS Optimization Tool kann als Kommandozeilen-Tool ausgeführt werden:
# VMwareOSOptimizationTool.exe -o -t <TemplateName>
# Template-Dateien: https://github.com/vmware/osot
# Write-VIDLog "OSOT ausführen..."
# $osotPath = "C:\Windows\Temp\VMwareOSOptimizationTool.exe"
# if (Test-Path $osotPath) {
#     Start-Process -FilePath $osotPath -ArgumentList "-o -t Win11_2x" -Wait -NoNewWindow
# }

Write-VIDLog "Horizon VDI Optimierungen abgeschlossen."
