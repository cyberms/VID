<#
    .DESCRIPTION
    Vendor Independence Day (VID) - Layer 7: Application Installation Framework

    Installiert Applikationen anhand des apps-manifest.json.
    Installer-Prioritaet: PSADT -> Winget (pinned) -> Chocolatey

    PSADT-Pakete werden vom VID-Data SMB-Share geladen, mit dem PSADT-Framework
    zusammengefuehrt und im DeployMode Silent ausgefuehrt.

    Manifest: packer/scripts/windows/apps-manifest.json
    PSADT:    packer/scripts/windows/psadt/
#>

param(
    [string]$ManifestPath   = "$PSScriptRoot\apps-manifest.json",
    [string]$PsadtFramework = "$PSScriptRoot\psadt\_framework",
    [string]$PsadtPackages  = "$PSScriptRoot\psadt\packages",
    [string]$SmbBase        = "\\$env:vid_smb_server\$env:vid_smb_share\apps",
    [switch]$WingetOnly,
    [switch]$ChocolateyOnly,
    [switch]$PsadtOnly,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Logs\VID\vid-apps-install.log"
New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

function Invoke-PsadtPackage {
    param([hashtable]$App, [string]$PsadtPath)
    Write-Log "  [PSADT] $($App.name) - Paketpfad: $PsadtPath"
    $tempDir = Join-Path $env:TEMP "VID_PSADT_$($App.name -replace '\s','_')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        Copy-Item -Path "$PsadtFramework\*" -Destination $tempDir -Recurse -Force
        Write-Log "  [PSADT] Framework kopiert."
        $localPackage = Join-Path $PsadtPackages $PsadtPath
        if (Test-Path "$localPackage\Deploy-Application.ps1") {
            Copy-Item -Path "$localPackage\Deploy-Application.ps1" -Destination $tempDir -Force
            if (Test-Path "$localPackage\Files") { Copy-Item -Path "$localPackage\Files" -Destination $tempDir -Recurse -Force }
            Write-Log "  [PSADT] Paket aus lokalem Pfad: $localPackage"
        } elseif (Test-Path "$SmbBase\$PsadtPath\Deploy-Application.ps1") {
            Copy-Item -Path "$SmbBase\$PsadtPath\Deploy-Application.ps1" -Destination $tempDir -Force
            if (Test-Path "$SmbBase\$PsadtPath\Files") { Copy-Item -Path "$SmbBase\$PsadtPath\Files" -Destination $tempDir -Recurse -Force }
            Write-Log "  [PSADT] Paket vom SMB-Share: $SmbBase\$PsadtPath"
        } else {
            Write-Log "  [PSADT] Kein Paket gefunden." "WARN"
            return $false
        }
        if ($DryRun) { Write-Log "  [DryRun] Deploy-Application.ps1 -DeploymentType Install -DeployMode Silent"; return $true }
        $psadtScript = Join-Path $tempDir "Deploy-Application.ps1"
        $proc = Start-Process "powershell.exe" `
            -ArgumentList "-ExecutionPolicy Bypass -NonInteractive -File `"$psadtScript`" -DeploymentType Install -DeployMode Silent" `
            -Wait -PassThru -WindowStyle Hidden
        Write-Log "  [PSADT] Exit Code: $($proc.ExitCode)"
        return $proc.ExitCode -in @(0, 3010)
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Winget {
    Write-Log "  Pruefe Winget..."
    if (Get-Command "winget" -ErrorAction SilentlyContinue) { Write-Log "  Winget verfuegbar."; return $true }
    Write-Log "  Winget nicht gefunden - versuche Installation..." "WARN"
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\winget.msixbundle"
        Add-AppxPackage -Path "$env:TEMP\winget.msixbundle" -ErrorAction Stop
        Write-Log "  Winget installiert."; return $true
    } catch { Write-Log "  Winget-Installation fehlgeschlagen: $($_.Exception.Message)" "WARN"; return $false }
}

function Install-AppViaWinget {
    param([hashtable]$App)
    $id = $App.winget_id; $version = $App.winget_version
    Write-Log "  [Winget] $($App.name) ($id$(if ($version) { " v$version" }))"
    if ($DryRun) { Write-Log "  [DryRun] winget install --id $id$(if ($version) { " --version $version" }) --silent"; return $true }
    $args = @("install","--id",$id,"--silent","--accept-package-agreements","--accept-source-agreements")
    if ($version) { $args += @("--version",$version) }
    & winget @args 2>&1 | Out-Null
    $exitCode = $LASTEXITCODE
    Write-Log "  [Winget] Exit Code: $exitCode"
    return $exitCode -in @(0, -1978335189, -1978335157)
}

function Install-Chocolatey {
    Write-Log "  Pruefe Chocolatey..."
    if (Get-Command "choco" -ErrorAction SilentlyContinue) { Write-Log "  Chocolatey verfuegbar."; return $true }
    Write-Log "  Installiere Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "  Chocolatey installiert."; return $true
    } catch { Write-Log "  Chocolatey-Installation fehlgeschlagen: $($_.Exception.Message)" "WARN"; return $false }
}

function Install-AppViaChocolatey {
    param([hashtable]$App)
    $id = $App.chocolatey_id
    Write-Log "  [Choco] $($App.name) ($id)"
    if ($DryRun) { Write-Log "  [DryRun] choco install $id -y --no-progress"; return $true }
    & choco install $id -y --no-progress 2>&1 | Out-Null
    $exitCode = $LASTEXITCODE
    Write-Log "  [Choco] Exit Code: $exitCode"
    return $exitCode -in @(0, 3010)
}

# ── Main ─────────────────────────────────────────────────────────────────────

Write-Log "========================================================"
Write-Log "=== VID Layer 7: Application Installation Framework  ==="
Write-Log "========================================================"
Write-Log "  Manifest  : $ManifestPath"
Write-Log "  Prioritaet: PSADT -> Winget (pinned) -> Chocolatey"
Write-Log "  DryRun    : $DryRun"

if (-not (Test-Path $ManifestPath)) { throw "App manifest not found: $ManifestPath" }

$manifest = Get-Content $ManifestPath | ConvertFrom-Json
Write-Log "  Manifest Version : $($manifest.version)"

$wingetAvailable = if (-not $ChocolateyOnly -and -not $PsadtOnly) { Install-Winget } else { $false }
$chocoAvailable  = if (-not $WingetOnly -and -not $PsadtOnly)     { Install-Chocolatey } else { $false }
$psadtAvailable  = Test-Path "$PsadtFramework\AppDeployToolkit\AppDeployToolkitMain.ps1"
Write-Log "  PSADT Framework: $(if ($psadtAvailable) { 'verfuegbar' } else { 'nicht gefunden - PSADT wird uebersprungen' })"

$vidReg = "HKLM:\SOFTWARE\VendorIndependenceDay"
if (-not (Test-Path $vidReg)) { New-Item $vidReg -Force | Out-Null }
Set-ItemProperty $vidReg "AppManifestVersion" $manifest.version -Type String

$totalInstalled = 0; $totalFailed = 0

foreach ($group in $manifest.groups) {
    Write-Log ""; Write-Log "--- Gruppe: $($group.name) ---"
    if ($group.enabled -eq $false) { Write-Log "  Gruppe deaktiviert."; continue }

    foreach ($appObj in $group.apps) {
        $app = @{
            name           = $appObj.name
            psadt_path     = $appObj.psadt_path
            winget_id      = $appObj.winget_id
            winget_version = $appObj.winget_version
            chocolatey_id  = $appObj.chocolatey_id
            enabled        = if ($null -ne $appObj.enabled) { $appObj.enabled } else { $true }
        }
        if ($app.enabled -eq $false) { Write-Log "  SKIP: $($app.name)"; continue }

        Write-Log ""; Write-Log "  -> $($app.name)"
        $success = $false

        # 1. PSADT
        if (-not $WingetOnly -and -not $ChocolateyOnly -and $psadtAvailable -and $app.psadt_path) {
            $success = Invoke-PsadtPackage -App $app -PsadtPath $app.psadt_path
            if ($success) { Write-Log "  OK PSADT: $($app.name)" }
            else          { Write-Log "  PSADT fehlgeschlagen - versuche Winget..." "WARN" }
        }

        # 2. Winget (pinned)
        if (-not $success -and $wingetAvailable -and $app.winget_id -and -not $ChocolateyOnly -and -not $PsadtOnly) {
            $success = Install-AppViaWinget -App $app
            if ($success) { Write-Log "  OK Winget: $($app.name)" }
            else          { Write-Log "  Winget fehlgeschlagen - versuche Chocolatey..." "WARN" }
        }

        # 3. Chocolatey
        if (-not $success -and $chocoAvailable -and $app.chocolatey_id -and -not $WingetOnly -and -not $PsadtOnly) {
            $success = Install-AppViaChocolatey -App $app
            if ($success) { Write-Log "  OK Chocolatey: $($app.name)" }
        }

        if ($success) { $totalInstalled++ }
        else { Write-Log "  FEHLGESCHLAGEN: $($app.name)" "WARN"; $totalFailed++ }
    }
}

Write-Log ""
Write-Log "=== Zusammenfassung: Installiert=$totalInstalled  Fehlgeschlagen=$totalFailed ==="
Write-Log "    Log: $LogFile"

exit $(if ($totalFailed -gt 0) { 1 } else { 0 })
