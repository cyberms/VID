<#
.SYNOPSIS
    VID Layer 7a – Microsoft Azure Virtual Desktop (AVD) Agent Installation

.DESCRIPTION
    Installiert den AVD RD Agent und AVD RD Agent Bootloader.
    Wird im Packer-Template windows/desktop/11-avd/ (azure-arm builder) verwendet.

    AVD Agent-Komponenten:
      1. Microsoft.RDInfra.RDAgent          – VDA-Äquivalent für AVD
      2. Microsoft.RDInfra.RDAgentBootLoader – Startet den RD Agent als Service

    Besonderheiten gegenüber Citrix:
      - Kein Registration Token im Image speichern! Token beim VM-Rollout via
        Terraform/ARM-Template übergeben (CustomScriptExtension oder Azure Policy).
      - Kein Sysprep – Azure verwaltet Identität via SID-Reset beim Provisioning.
      - FSLogix für Profile (nicht Citrix UPM).
      - Azure Compute Gallery statt vSphere Content Library für Image-Storage.

    Installer-Download (VID-Data SMB-Share oder direkt):
      https://aka.ms/rdagentbootloader
      https://aka.ms/rdagent

.NOTES
    VID Layer  : 7a – Broker Agent
    Broker     : Microsoft Azure Virtual Desktop (AVD / WVD)
    Maintainer : VID-Team
    Status     : STUB – Installer-URL / Registrierung vor Produktiveinsatz anpassen!
    Template   : windows/desktop/11-avd/ (azure-arm builder)
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-avd-agent.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7a – AVD Agent Installation"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "═══════════════════════════════════════════════"

# ── Option A: Installer vom VID-Data SMB-Share ────────────────────────────────
# $smbServer   = $env:VID_SMB_SERVER
# $smbShare    = $env:VID_SMB_SHARE
# $smbUsername = $env:VID_SMB_USERNAME
# $smbPassword = $env:VID_SMB_PASSWORD
# $bootloader  = $env:VID_AVD_BOOTLOADER    # z.B. "Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi"
# $agent       = $env:VID_AVD_AGENT         # z.B. "Microsoft.RDInfra.RDAgent.Installer-x64-1.0.xxxx.msi"

# ── Option B: Direkter Download (empfohlen für Azure-native Builds) ───────────
# Im azure-arm Builder hat die VM Internetzugang – Installer direkt herunterladen

$tempDir       = "C:\Windows\Temp\avd-install"
$bootloaderMsi = "$tempDir\RDAgentBootLoader.msi"
$agentMsi      = "$tempDir\RDAgent.msi"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-VIDLog "Lade AVD Installer herunter..."

# AVD BootLoader
$bootloaderUrl = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"  # aka.ms/rdagentbootloader
Invoke-WebRequest -Uri $bootloaderUrl -OutFile $bootloaderMsi -UseBasicParsing
Write-VIDLog "BootLoader heruntergeladen: $bootloaderMsi"

# AVD RD Agent (aktuellste Version über AKA-Link)
$agentUrl = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXr"       # aka.ms/rdagent
Invoke-WebRequest -Uri $agentUrl -OutFile $agentMsi -UseBasicParsing
Write-VIDLog "RD Agent heruntergeladen: $agentMsi"

# ── 1. BootLoader installieren ────────────────────────────────────────────────
Write-VIDLog "Installiere AVD RD Agent BootLoader..."
$p = Start-Process -FilePath "msiexec.exe" `
                   -ArgumentList "/i `"$bootloaderMsi`" /qn /norestart" `
                   -Wait -PassThru -NoNewWindow
Write-VIDLog "BootLoader Exit-Code: $($p.ExitCode)"

# ── 2. RD Agent installieren ──────────────────────────────────────────────────
# WICHTIG: REGISTRATIONTOKEN NICHT IM IMAGE SPEICHERN!
# Token wird beim Rollout via Custom Script Extension übergeben.
# Für Packer-Build: REGISTRATIONTOKEN leer lassen → Agent startet ohne Pool-Registrierung
Write-VIDLog "Installiere AVD RD Agent (ohne Registration Token)..."
$p = Start-Process -FilePath "msiexec.exe" `
                   -ArgumentList "/i `"$agentMsi`" /qn /norestart REGISTRATIONTOKEN=" `
                   -Wait -PassThru -NoNewWindow
Write-VIDLog "RD Agent Exit-Code: $($p.ExitCode)"

# ── Cleanup ───────────────────────────────────────────────────────────────────
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# ── VID Registry: AVD Agent dokumentieren ─────────────────────────────────────
$key = "HKLM:\SOFTWARE\VendorIndependenceDay\InstalledApps\AVD_RDAgent"
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name "IsInstalled"          -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name "AppName"              -Value "AVD RD Agent"
Set-ItemProperty -Path $key -Name "InstallationDateTime" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-VIDLog "AVD Agent Installation abgeschlossen. Neustart durch Packer folgt."
