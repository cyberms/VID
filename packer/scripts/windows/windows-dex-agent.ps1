<#
    .DESCRIPTION
    VID Layer 8 – DEX / Monitoring Agent Installation
    Installiert ControlUp Agent und/oder uberagent im Master Image.

    Die Agenten werden OHNE Serverkonfiguration installiert.
    Verbindungsparameter (Monitor-Server, Backend-URL, Lizenz) werden
    ausschließlich über Gruppenrichtlinien (Layer 4) verteilt – niemals im Image.

    .PARAMETER InstallControlUp
    Installiert den ControlUp Real-time Agent (Standard: $true)

    .PARAMETER InstallUberagent
    Installiert uberagent von vastlimits/Citrix (Standard: $true)

    .PARAMETER InstallUberagentESA
    Installiert uberagent Endpoint Security Analytics (Standard: $false)

    .PARAMETER InstallerSourcePath
    Pfad zum Verzeichnis mit den Installer-Dateien.
    Standard: Sucht auf allen gemounteten CD-ROM-Laufwerken nach Installern.

    .NOTES
    Unterstützte Installer-Dateinamen:
      ControlUp: CUAgent.exe, CUAgent.msi, ControlUpAgent*.exe, ControlUpAgent*.msi
      uberagent:  uberagent*.msi, uberagent-*.msi
      uberagentESA: uberagentESA*.msi, uberagent-esa*.msi

    VID-Prinzip:
      Agent im Image (Layer 8) = austauschbar ohne OS-Rebuild
      Config via GPO (Layer 4)  = niemals hardcodiert
#>

param(
    [switch]$InstallControlUp    = $true,
    [switch]$InstallUberagent    = $true,
    [switch]$InstallUberagentESA = $false,
    [string]$InstallerSourcePath = ""
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\dex-agent-install.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

function Find-Installer {
    param([string[]]$FilePatterns, [string]$SourcePath = "")

    # 1. Expliziter Pfad angegeben
    if ($SourcePath -and (Test-Path $SourcePath)) {
        foreach ($pattern in $FilePatterns) {
            $found = Get-ChildItem -Path $SourcePath -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    # 2. Alle CD-ROM-Laufwerke durchsuchen
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object {
        $_.DriveType -eq 'CDRom' -and $_.IsReady
    }
    foreach ($drive in $drives) {
        foreach ($pattern in $FilePatterns) {
            $found = Get-ChildItem -Path $drive.RootDirectory -Filter $pattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                Write-Log "  Installer gefunden auf $($drive.Name): $($found.FullName)"
                return $found.FullName
            }
        }
    }

    # 3. Skript-Verzeichnis
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if ($scriptDir) {
        foreach ($pattern in $FilePatterns) {
            $found = Get-ChildItem -Path $scriptDir -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    return $null
}

function Install-Msi {
    param([string]$MsiPath, [string]$AdditionalArgs = "")
    $args = "/i `"$MsiPath`" /quiet /norestart $AdditionalArgs".Trim()
    Write-Log "  msiexec $args"
    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru
    return $proc.ExitCode
}

function Install-Exe {
    param([string]$ExePath, [string]$Arguments)
    Write-Log "  $ExePath $Arguments"
    $proc = Start-Process -FilePath $ExePath -ArgumentList $Arguments -Wait -PassThru
    return $proc.ExitCode
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Log "=== VID Layer 8 – DEX Agent Installation ==="
Write-Log "ControlUp:     $InstallControlUp"
Write-Log "uberagent:     $InstallUberagent"
Write-Log "uberagent ESA: $InstallUberagentESA"
Write-Log "Source Path:   $(if ($InstallerSourcePath) { $InstallerSourcePath } else { 'CD-ROM Auto-Detect' })"

$anyInstalled = $false
$errors = @()

# ─────────────────────────────────────────────────────────────────────────────
# 1. ControlUp Agent
# ─────────────────────────────────────────────────────────────────────────────

if ($InstallControlUp) {
    Write-Log "--- [1] ControlUp Agent ---"

    $cuPatterns = @(
        "CUAgent.msi",
        "CUAgent.exe",
        "ControlUpAgent*.msi",
        "ControlUpAgent*.exe",
        "ControlUp*Agent*.msi",
        "ControlUp*Agent*.exe"
    )

    $installer = Find-Installer -FilePatterns $cuPatterns -SourcePath $InstallerSourcePath

    if ($installer) {
        Write-Log "  Installer: $installer"
        $ext = [System.IO.Path]::GetExtension($installer).ToLower()

        # WICHTIG: Kein MONITOR-Parameter – Serverkonfiguration kommt via GPO
        # GPO-Pfad: HKLM\SOFTWARE\Smart-X\ControlUp\Agent → MonitorAddress
        if ($ext -eq ".msi") {
            $exitCode = Install-Msi -MsiPath $installer
        } else {
            # EXE-Silent-Install
            $exitCode = Install-Exe -ExePath $installer -Arguments "/S /v`"/qn`""
        }

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Log "  ControlUp Agent installiert (ExitCode: $exitCode)"
            $anyInstalled = $true

            # Dienst prüfen
            $svc = Get-Service -Name "ControlUp*" -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Log "  Dienst gefunden: $($svc.Name) | Status: $($svc.Status)"
                # Im Master Image stoppen – startet nach MCS-Provisionierung
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc.Name -StartupType Automatic
                Write-Log "  Dienst auf Automatic gesetzt (startet nach Boot)."
            }

            Write-Log "  HINWEIS: Monitor-Server via GPO konfigurieren:"
            Write-Log "    HKLM\SOFTWARE\Smart-X\ControlUp\Agent → MonitorAddress = <server-fqdn>"
        } else {
            $msg = "ControlUp Agent Installation fehlgeschlagen (ExitCode: $exitCode)"
            Write-Log "  $msg" "WARN"
            $errors += $msg
        }
    } else {
        Write-Log "  Kein ControlUp Installer gefunden – übersprungen." "WARN"
        Write-Log "  Installer auf CD-ROM mounten oder InstallerSourcePath angeben."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. uberagent
# ─────────────────────────────────────────────────────────────────────────────

if ($InstallUberagent) {
    Write-Log "--- [2] uberagent ---"

    $uaPatterns = @(
        "uberagent.msi",
        "uberagent-*.msi",
        "uberagent_*.msi",
        "uberagent*.msi"
    )
    # ESA hat eigenes MSI – hier nur Basis-Agent
    $uaPatterns = $uaPatterns | Where-Object { $_ -notmatch "esa" }

    $installer = Find-Installer -FilePatterns $uaPatterns -SourcePath $InstallerSourcePath

    if ($installer) {
        Write-Log "  Installer: $installer"

        # WICHTIG: Keine RECEIVER_URL – Backend-Konfiguration kommt via uberagent.conf (GPO/SYSVOL)
        # Konfigurationsdatei-Pfad: C:\Program Files\vast limits\uberagent\uberagent.conf
        $exitCode = Install-Msi -MsiPath $installer

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Log "  uberagent installiert (ExitCode: $exitCode)"
            $anyInstalled = $true

            # Dienst deaktivieren bis Konfiguration via GPO verteilt wurde
            $svc = Get-Service -Name "uberagent" -ErrorAction SilentlyContinue
            if ($svc) {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                # Delayed Auto Start für bessere Boot-Performance in VDI
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\uberagent" `
                    -Name "Start" -Value 2 -ErrorAction SilentlyContinue  # 2 = Automatic
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\uberagent" `
                    -Name "DelayedAutostart" -Value 1 -ErrorAction SilentlyContinue
                Write-Log "  Dienst auf Delayed Automatic Start gesetzt."
            }

            Write-Log "  HINWEIS: uberagent.conf via GPO oder SYSVOL verteilen:"
            Write-Log "    Pfad: C:\Program Files\vast limits\uberagent\uberagent.conf"
            Write-Log "    Mindest-Config: [Receiver] Url = https://<splunk-hec-url>"
        } else {
            $msg = "uberagent Installation fehlgeschlagen (ExitCode: $exitCode)"
            Write-Log "  $msg" "WARN"
            $errors += $msg
        }
    } else {
        Write-Log "  Kein uberagent Installer gefunden – übersprungen." "WARN"
        Write-Log "  Installer auf CD-ROM mounten oder InstallerSourcePath angeben."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. uberagent ESA (Endpoint Security Analytics) – optional
# ─────────────────────────────────────────────────────────────────────────────

if ($InstallUberagentESA) {
    Write-Log "--- [3] uberagent ESA (Endpoint Security Analytics) ---"

    $esaPatterns = @(
        "uberagentESA.msi",
        "uberagentESA-*.msi",
        "uberagent-esa*.msi",
        "uberagent*ESA*.msi"
    )

    $installer = Find-Installer -FilePatterns $esaPatterns -SourcePath $InstallerSourcePath

    if ($installer) {
        Write-Log "  Installer: $installer"
        $exitCode = Install-Msi -MsiPath $installer

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Log "  uberagent ESA installiert (ExitCode: $exitCode)"
            $anyInstalled = $true
        } else {
            $msg = "uberagent ESA Installation fehlgeschlagen (ExitCode: $exitCode)"
            Write-Log "  $msg" "WARN"
            $errors += $msg
        }
    } else {
        Write-Log "  Kein uberagent ESA Installer gefunden – übersprungen." "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Windows Defender Ausnahmen für DEX-Agenten
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [4] Defender-Ausnahmen für DEX-Agenten ---"

$defenderExclusions = @(
    "$env:ProgramFiles\Smart-X",            # ControlUp
    "$env:ProgramFiles\ControlUp",          # ControlUp (neuere Versionen)
    "$env:ProgramFiles\vast limits",        # uberagent
    "$env:ProgramData\vast limits",         # uberagent Daten
    "$env:ProgramFiles\Citrix\uberagent"    # uberagent (Citrix-Branding)
)

foreach ($path in $defenderExclusions) {
    Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
    Write-Log "  Defender-Ausnahme: $path"
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Registry-Marker für VID Layer 8
# ─────────────────────────────────────────────────────────────────────────────

$vidRegPath = "HKLM:\SOFTWARE\VendorIndependenceDay\Layer8"
New-Item -Path $vidRegPath -Force | Out-Null
Set-ItemProperty -Path $vidRegPath -Name "ControlUpInstalled" -Value ([int]$InstallControlUp) -Type DWord
Set-ItemProperty -Path $vidRegPath -Name "UberagentInstalled"  -Value ([int]$InstallUberagent) -Type DWord
Set-ItemProperty -Path $vidRegPath -Name "BuildDate"           -Value (Get-Date -Format "yyyy-MM-dd") -Type String
Write-Log "VID Registry-Marker gesetzt: $vidRegPath"

# ─────────────────────────────────────────────────────────────────────────────
# Zusammenfassung
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "=== DEX Agent Installation abgeschlossen ==="

if ($errors.Count -gt 0) {
    Write-Log "WARNUNGEN ($($errors.Count)):" "WARN"
    $errors | ForEach-Object { Write-Log "  - $_" "WARN" }
}

if (-not $anyInstalled) {
    Write-Log "HINWEIS: Kein DEX-Agent installiert. Installer nicht gefunden." "WARN"
    Write-Log "         Skript trotzdem erfolgreich – DEX ist optional in Layer 8."
}

Write-Log "Log: $LogFile"
