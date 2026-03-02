<#
    .DESCRIPTION
    Vendor Independence Day (VID) - Layer 7: Application Installation Framework
    
    Reads an application manifest (apps-manifest.json) and installs applications
    using Winget (preferred) or Chocolatey (fallback) or direct download.
    
    Layer 7 is independent of Layer 5 (OS) and Layer 6 (Drivers).
    The same manifest can be applied to any VID-compliant Windows 11 image.
    
    Usage: Can be run:
      - During Packer image build (applications baked into image)
      - At VM first boot (applications installed post-provisioning)
      - Via Citrix DaaS provisioning script
      - Standalone on any Windows 11 machine
    
    Manifest: packer/scripts/windows/apps-manifest.json
#>

param(
    [string]$ManifestPath = "$PSScriptRoot\apps-manifest.json",
    [switch]$WingetOnly,
    [switch]$ChocolateyOnly,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\vid-apps-install.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

function Install-Winget {
    Write-Log "  Checking Winget availability..."
    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Log "  Winget found: $($winget.Source)"
        return $true
    }
    Write-Log "  Winget not found. Attempting installation via AppX..." "WARN"
    try {
        # Install WinGet via Microsoft.UI.Xaml dependency
        $progPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "C:\Windows\Temp\winget.msixbundle"
        Add-AppxPackage -Path "C:\Windows\Temp\winget.msixbundle" -ErrorAction Stop
        $ProgressPreference = $progPreference
        Write-Log "  Winget installed successfully."
        return $true
    }
    catch {
        Write-Log "  Winget installation failed: $($_.Exception.Message)" "WARN"
        return $false
    }
}

function Install-Chocolatey {
    Write-Log "  Checking Chocolatey availability..."
    if (Get-Command "choco" -ErrorAction SilentlyContinue) {
        Write-Log "  Chocolatey already installed."
        return $true
    }
    Write-Log "  Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "  Chocolatey installed successfully."
        return $true
    }
    catch {
        Write-Log "  Chocolatey installation failed: $($_.Exception.Message)" "WARN"
        return $false
    }
}

function Install-AppViaWinget {
    param([hashtable]$App)
    $id = $App.winget_id
    Write-Log "  [Winget] Installing: $($App.name) ($id)"
    if ($DryRun) { Write-Log "  [DryRun] winget install --id $id --silent --accept-package-agreements --accept-source-agreements"; return $true }
    
    $result = & winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1
    $exitCode = $LASTEXITCODE
    Write-Log "  [Winget] Exit code: $exitCode"
    return $exitCode -in @(0, -1978335189) # 0=success, -1978335189=already installed
}

function Install-AppViaChocolatey {
    param([hashtable]$App)
    $id = $App.chocolatey_id
    Write-Log "  [Choco] Installing: $($App.name) ($id)"
    if ($DryRun) { Write-Log "  [DryRun] choco install $id -y --no-progress"; return $true }
    
    $result = & choco install $id -y --no-progress 2>&1
    $exitCode = $LASTEXITCODE
    Write-Log "  [Choco] Exit code: $exitCode. Output: $(($result | Select-Object -Last 3) -join '; ')"
    return $exitCode -eq 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "=== VID Layer 7: Application Installation Framework ==="
Write-Log "  Manifest: $ManifestPath"
Write-Log "  DryRun:   $DryRun"

# Load manifest
if (-not (Test-Path $ManifestPath)) {
    Write-Log "  ERROR: Manifest not found: $ManifestPath" "ERROR"
    throw "App manifest not found: $ManifestPath"
}

$manifest = Get-Content $ManifestPath | ConvertFrom-Json
Write-Log "  Manifest version: $($manifest.version)"
Write-Log "  Application groups: $($manifest.groups.Count)"

# Initialize package managers
$wingetAvailable = Install-Winget
$chocoAvailable  = Install-Chocolatey

# Write VID Layer 7 registry info
$vidRegPath = "HKLM:\SOFTWARE\VendorIndependenceDay"
if (-not (Test-Path $vidRegPath)) { New-Item $vidRegPath -Force | Out-Null }
Set-ItemProperty $vidRegPath "AppManifestVersion" $manifest.version -Type String

# Process each application group
$totalInstalled = 0
$totalFailed    = 0

foreach ($group in $manifest.groups) {
    Write-Log ""
    Write-Log "--- Group: $($group.name) ---"
    
    if ($group.enabled -eq $false) {
        Write-Log "  Group disabled, skipping."
        continue
    }

    foreach ($appObj in $group.apps) {
        $app = @{
            name           = $appObj.name
            winget_id      = $appObj.winget_id
            chocolatey_id  = $appObj.chocolatey_id
            enabled        = if ($null -ne $appObj.enabled) { $appObj.enabled } else { $true }
        }

        if ($app.enabled -eq $false) {
            Write-Log "  SKIP (disabled): $($app.name)"
            continue
        }

        Write-Log "  Installing: $($app.name)"
        $success = $false

        if ($wingetAvailable -and $app.winget_id -and -not $ChocolateyOnly) {
            $success = Install-AppViaWinget -App $app
        }
        if (-not $success -and $chocoAvailable -and $app.chocolatey_id -and -not $WingetOnly) {
            $success = Install-AppViaChocolatey -App $app
        }

        if ($success) {
            Write-Log "  SUCCESS: $($app.name)"
            $totalInstalled++
        } else {
            Write-Log "  FAILED: $($app.name)" "WARN"
            $totalFailed++
        }
    }
}

Write-Log ""
Write-Log "=== VID Layer 7: Application Installation Summary ==="
Write-Log "  Installed: $totalInstalled"
Write-Log "  Failed:    $totalFailed"
Write-Log "  Log: $LogFile"
