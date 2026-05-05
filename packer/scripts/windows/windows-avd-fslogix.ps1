<#
.SYNOPSIS
    VID Layer 7b – Microsoft FSLogix für AVD (Profil-Container)

.DESCRIPTION
    Installiert und konfiguriert FSLogix für Azure Virtual Desktop.
    FSLogix ist das Standard-Profil-Management für AVD (entspricht Citrix UPM).

    FSLogix Profil-Container:
      - Profile werden als VHDX in Azure Files oder auf einem File Server gespeichert
      - Schnelleres Anmelden als Roaming Profiles
      - Unterstützt Office 365 Container für Outlook-Cache und Teams

    VHDLocations Beispiele:
      - Azure Files: \\<storage>.file.core.windows.net\<share>
      - Azure NetApp Files: \\<netapp-ip>\<volume>
      - On-Premises File Server: \\<server>\<share>

.NOTES
    VID Layer  : 7b – Broker Optimizations / Profile
    Broker     : Microsoft Azure Virtual Desktop (AVD)
    Maintainer : VID-Team
    Status     : STUB – VHDLocations vor Produktiveinsatz setzen!
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-avd-fslogix.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – FSLogix Installation & Konfiguration"
Write-VIDLog "═══════════════════════════════════════════════"

# ── FSLogix herunterladen oder vom SMB-Share ──────────────────────────────────
# FSLogix ist in Microsoft 365 E3/E5 und AVD-Lizenz enthalten (kostenlos)
# Download: https://aka.ms/fslogix-latest

$tempDir   = "C:\Windows\Temp\fslogix-install"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-VIDLog "FSLogix herunterladen..."
$fslogixZip = "$tempDir\FSLogix.zip"
Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile $fslogixZip -UseBasicParsing
Expand-Archive -Path $fslogixZip -DestinationPath $tempDir -Force

# FSLogix Apps Installer (x64)
$installer = Get-ChildItem -Path $tempDir -Recurse -Filter "FSLogixAppsSetup.exe" |
             Where-Object { $_.FullName -match "x64" } | Select-Object -First 1

Write-VIDLog "Installiere FSLogix: $($installer.FullName)"
$p = Start-Process -FilePath $installer.FullName `
                   -ArgumentList "/install /quiet /norestart" `
                   -Wait -PassThru -NoNewWindow
Write-VIDLog "FSLogix Exit-Code: $($p.ExitCode)"

# ── FSLogix Profil-Container konfigurieren ────────────────────────────────────
# HINWEIS: VHDLocations im Image als Platzhalter – beim Rollout via GPO oder
#          Intune/Azure Policy mit tatsächlichem Storage-Pfad überschreiben!

$fslKey = "HKLM:\SOFTWARE\FSLogix\Profiles"
New-Item -Path $fslKey -Force | Out-Null

# Basis-Konfiguration
Set-ItemProperty -Path $fslKey -Name "Enabled"                   -Value 1 -Type DWord
Set-ItemProperty -Path $fslKey -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -Type DWord
Set-ItemProperty -Path $fslKey -Name "FlipFlopProfileDirectoryName"         -Value 1 -Type DWord
Set-ItemProperty -Path $fslKey -Name "SizeInMBs"                 -Value 30720 -Type DWord   # 30 GB default
Set-ItemProperty -Path $fslKey -Name "VolumeType"                -Value "VHDX" -Type String

# TODO: VHDLocations mit tatsächlichem Storage-Pfad setzen
# z.B. für Azure Files: \\<storageaccount>.file.core.windows.net\profiles
# Set-ItemProperty -Path $fslKey -Name "VHDLocations" -Value "\\storageaccount.file.core.windows.net\profiles" -Type String
Write-VIDLog "HINWEIS: VHDLocations nicht gesetzt – via GPO/Intune beim Rollout konfigurieren!"

# ── Office 365 Container konfigurieren ────────────────────────────────────────
$o365Key = "HKLM:\SOFTWARE\FSLogix\Apps"
New-Item -Path $o365Key -Force | Out-Null
Set-ItemProperty -Path $o365Key -Name "RoamSearch" -Value 2 -Type DWord

# ── FSLogix Cleanup (Temp) ────────────────────────────────────────────────────
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# ── VID Registry ──────────────────────────────────────────────────────────────
$key = "HKLM:\SOFTWARE\VendorIndependenceDay\InstalledApps\Microsoft_FSLogix"
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name "IsInstalled"          -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name "AppName"              -Value "Microsoft FSLogix Apps"
Set-ItemProperty -Path $key -Name "InstallationDateTime" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-VIDLog "FSLogix Installation und Konfiguration abgeschlossen."
