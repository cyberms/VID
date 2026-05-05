<#
.SYNOPSIS
    VID Layer 7a – VMware / Broadcom Horizon Agent Installation

.DESCRIPTION
    Installiert den Horizon Agent silent vom VID-Data SMB-Share.
    Äquivalent zu windows-citrix-vda.ps1 für Citrix.

    SMB-Pfad: \\<VID_SMB_SERVER>\<VID_SMB_SHARE>\vmware\horizon\<VID_HORIZON_INSTALLER>

    Typische Installer-Parameter (Horizon 2312+):
      /s /v "/qn
        VDM_VC_MANAGED_AGENT=1
        ADDLOCAL=Core,RTAV,ClientDriveRedirection,V4V,VmwVaudio,PCoIP,Blast,USB
        REBOOT=ReallySuppress"

    Referenz:
      https://docs.vmware.com/en/VMware-Horizon/2312/horizon-installation/GUID-silent-installer.html

.NOTES
    VID Layer  : 7a – Broker Agent
    Broker     : VMware / Broadcom Horizon (Instant Clone)
    Maintainer : VID-Team
    Status     : STUB – Installer-Parameter vor Produktiveinsatz anpassen!
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ── Logging ─────────────────────────────────────────────────────────────────

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-horizon-agent.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7a – Horizon Agent Installation"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "═══════════════════════════════════════════════"

# ── Parameter aus Umgebungsvariablen ─────────────────────────────────────────

$smbServer    = $env:VID_SMB_SERVER
$smbShare     = $env:VID_SMB_SHARE
$smbUsername  = $env:VID_SMB_USERNAME
$smbPassword  = $env:VID_SMB_PASSWORD
$installer    = $env:VID_HORIZON_INSTALLER

if ([string]::IsNullOrEmpty($installer)) {
    Write-VIDLog "FEHLER: VID_HORIZON_INSTALLER nicht gesetzt." -Level "ERROR"
    exit 1
}

# ── SMB-Share verbinden ──────────────────────────────────────────────────────

$sharePath = "\\$smbServer\$smbShare"
Write-VIDLog "Verbinde SMB-Share: $sharePath"

$secPassword = ConvertTo-SecureString $smbPassword -AsPlainText -Force
$credential  = New-Object System.Management.Automation.PSCredential($smbUsername, $secPassword)

New-PSDrive -Name "VIDData" -PSProvider FileSystem -Root $sharePath -Credential $credential -ErrorAction Stop | Out-Null
Write-VIDLog "SMB-Share verbunden."

try {
    # ── Installer in Temp kopieren ────────────────────────────────────────────

    $installerSrc  = "VIDData:\vmware\horizon\$installer"
    $installerDst  = "C:\Windows\Temp\$installer"

    Write-VIDLog "Kopiere Installer: $installerSrc → $installerDst"
    Copy-Item -Path $installerSrc -Destination $installerDst -Force
    Write-VIDLog "Installer kopiert: $('{0:N0}' -f (Get-Item $installerDst).Length) Bytes"

    # ── Horizon Agent installieren ────────────────────────────────────────────
    # TODO: Komponenten-Liste anpassen (Core ist Pflicht, Blast für DaaS empfohlen)
    # Referenz: https://docs.vmware.com/en/VMware-Horizon/

    $components = "Core,RTAV,ClientDriveRedirection,VmwVaudio,Blast,USB"
    $msiArgs    = "/qn VDM_VC_MANAGED_AGENT=1 ADDLOCAL=$components REBOOT=ReallySuppress"

    Write-VIDLog "Starte Horizon Agent Installation..."
    Write-VIDLog "  Installer: $installerDst"
    Write-VIDLog "  Argumente: /s /v `"$msiArgs`""

    $proc = Start-Process -FilePath $installerDst `
                          -ArgumentList "/s /v `"$msiArgs`"" `
                          -Wait -PassThru -NoNewWindow

    Write-VIDLog "Exit-Code: $($proc.ExitCode)"

    switch ($proc.ExitCode) {
        0     { Write-VIDLog "Horizon Agent erfolgreich installiert." }
        3010  { Write-VIDLog "Horizon Agent installiert – Neustart erforderlich." }
        3011  { Write-VIDLog "Horizon Agent installiert – Neustart erforderlich (3011)." }
        default {
            Write-VIDLog "UNBEKANNTER Exit-Code: $($proc.ExitCode)" -Level "WARN"
        }
    }
}
finally {
    # SMB-Share trennen
    if (Get-PSDrive -Name "VIDData" -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name "VIDData" -Force
    }
    # Installer löschen
    Remove-Item -Path "C:\Windows\Temp\$installer" -Force -ErrorAction SilentlyContinue
    Write-VIDLog "Cleanup abgeschlossen."
}

Write-VIDLog "Horizon Agent Installation beendet. Neustart durch Packer folgt."
