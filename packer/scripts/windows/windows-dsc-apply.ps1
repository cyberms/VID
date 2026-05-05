<#
.SYNOPSIS
    VID DSC Bootstrap – OS Baseline anwenden (Layer 5)

.DESCRIPTION
    Kompiliert die DSC-Konfiguration VID-OSBaseline und wendet sie an.
    Wird von Packer als Ersatz für windows-prepare.ps1 in scripts_layer5 aufgerufen.

    Ablauf:
      1. LCM auf ApplyOnly konfigurieren (kein Pull-Server, kein Monitoring)
      2. VID-OSBaseline.ps1 laden und kompilieren (→ MOF in C:\Windows\Temp\VID-DSC\)
      3. Start-DscConfiguration anwenden
      4. Test-DscConfiguration: Ergebnis ins VID-Log schreiben

    Log-Pfad: C:\Windows\Logs\VID\vid-dsc-baseline.log

.NOTES
    VID Layer  : 5 – OS Baseline
    Maintainer : VID-Team
    Created    : 2026-05-05
#>

[CmdletBinding()]
param(
    [string]$BuildUsername = $env:BUILD_USERNAME
)

$ErrorActionPreference = "Stop"

# ── Logging ─────────────────────────────────────────────────────────────────

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-dsc-baseline.log"

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

Write-VIDLog "═══════════════════════════════════════════════════════"
Write-VIDLog "VID DSC Bootstrap – OS Baseline (Layer 5)"
Write-VIDLog "Build-User: $BuildUsername"
Write-VIDLog "═══════════════════════════════════════════════════════"


# ── Schritt 1: LCM auf ApplyOnly konfigurieren ──────────────────────────────

Write-VIDLog "Schritt 1: LCM konfigurieren (ApplyOnly, Push)..."

[DSCLocalConfigurationManager()]
Configuration VID_LCM {
    Node "localhost" {
        Settings {
            RebootNodeIfNeeded   = $false
            ConfigurationMode    = "ApplyOnly"
            ActionAfterReboot    = "ContinueConfiguration"
            RefreshMode          = "Push"
        }
    }
}

$lcmMofDir = "C:\Windows\Temp\VID-LCM"
if (-not (Test-Path $lcmMofDir)) { New-Item -ItemType Directory -Path $lcmMofDir -Force | Out-Null }
VID_LCM -OutputPath $lcmMofDir | Out-Null
Set-DscLocalConfigurationManager -Path $lcmMofDir -Force
Write-VIDLog "LCM erfolgreich auf ApplyOnly gesetzt."


# ── Schritt 2: DSC-Konfiguration kompilieren ────────────────────────────────

Write-VIDLog "Schritt 2: VID-OSBaseline.ps1 laden und kompilieren..."

$dscScript = "$PSScriptRoot\dsc\VID-OSBaseline.ps1"
if (-not (Test-Path $dscScript)) {
    Write-VIDLog "FEHLER: DSC-Konfiguration nicht gefunden: $dscScript" -Level "ERROR"
    exit 1
}

# Konfiguration in diese Session laden
. $dscScript

$mofDir = "C:\Windows\Temp\VID-DSC"
if (Test-Path $mofDir) { Remove-Item $mofDir -Recurse -Force }
New-Item -ItemType Directory -Path $mofDir -Force | Out-Null

try {
    VID-OSBaseline -BuildUsername $BuildUsername -OutputPath $mofDir | Out-Null
    Write-VIDLog "MOF kompiliert: $mofDir\localhost.mof"
}
catch {
    Write-VIDLog "FEHLER beim Kompilieren der DSC-Konfiguration: $_" -Level "ERROR"
    exit 1
}


# ── Schritt 3: DSC-Konfiguration anwenden ───────────────────────────────────

Write-VIDLog "Schritt 3: DSC-Konfiguration anwenden (Start-DscConfiguration)..."

try {
    Start-DscConfiguration -Path $mofDir -Wait -Force -Verbose 4>&1 | ForEach-Object {
        Write-VIDLog "  [DSC] $_"
    }
    Write-VIDLog "Start-DscConfiguration abgeschlossen."
}
catch {
    Write-VIDLog "FEHLER bei Start-DscConfiguration: $_" -Level "ERROR"
    exit 1
}


# ── Schritt 4: Verifikation ─────────────────────────────────────────────────

Write-VIDLog "Schritt 4: Test-DscConfiguration (Compliance-Prüfung)..."

try {
    $testResult = Test-DscConfiguration -Detailed -ErrorAction SilentlyContinue

    if ($testResult.InDesiredState) {
        Write-VIDLog "✓ DSC-Compliance: InDesiredState = TRUE – alle Ressourcen korrekt konfiguriert."
    }
    else {
        Write-VIDLog "⚠ DSC-Compliance: InDesiredState = FALSE – abweichende Ressourcen:" -Level "WARN"
        foreach ($r in $testResult.ResourcesNotInDesiredState) {
            Write-VIDLog "  ✗ $($r.ResourceId)" -Level "WARN"
        }
        # Kein exit 1 – Abweichungen loggen aber Build nicht abbrechen (z.B. WSearch auf manchen W11-Versionen)
    }
}
catch {
    Write-VIDLog "Test-DscConfiguration fehlgeschlagen (nicht kritisch): $_" -Level "WARN"
}


# ── Abschluss ────────────────────────────────────────────────────────────────

Write-VIDLog "VID DSC OS-Baseline erfolgreich angewendet."
Write-VIDLog "Log: $logFile"
