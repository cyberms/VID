<#
    .DESCRIPTION
    Vendor Independence Day (VID) - Layer 6: XenServer/Citrix Hypervisor Guest Tools
    
    Installs Citrix VM Tools (XenTools) for Citrix Hypervisor / XenServer.
    
    Drivers installed:
    - XenBus (PV Bus driver)
    - XenNet (Paravirtual Network Adapter)
    - XenVbd (Paravirtual Block Device / Storage)
    - XenGfx (Graphics driver)
    - Management Agent (xe-guest-utilities equivalent for Windows)
    
    The Citrix VM Tools ISO must be mounted as a CD-ROM drive (auto-detected).
    ISO download: https://www.xenserver.com/downloads
    File name pattern: managementagent-<version>-x86_64.msi or CitrixVMTools*.exe
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\vid-xenserver-tools.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

Write-Log "=== VID Layer 6: Citrix VM Tools (XenServer) Installation ==="

# ─────────────────────────────────────────────────────────────────────────────
# 1. Find the Citrix VM Tools installer
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- [1] Locating Citrix VM Tools Installer ---"

$installer = $null
$drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'CDRom' -and $_.IsReady }

$installerPatterns = @(
    "CitrixVMTools*.exe",
    "managementagent*.msi",
    "XenToolsSetup*.exe",
    "xentools*.exe",
    "installwizard.msi"
)

foreach ($drive in $drives) {
    Write-Log "  Checking drive $($drive.Name)..."
    foreach ($pattern in $installerPatterns) {
        $candidate = Get-ChildItem -Path $drive.RootDirectory -Filter $pattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) {
            $installer = $candidate
            Write-Log "  Found installer: $($installer.FullName) (Pattern: $pattern)"
            break
        }
    }
    if ($installer) { break }
}

if (-not $installer) {
    Write-Log "  ERROR: Citrix VM Tools installer not found on any CD-ROM drive." "ERROR"
    Write-Log "  Drives checked: $(($drives | ForEach-Object { $_.Name }) -join ', ')"
    Write-Log "  Please mount the Citrix VM Tools ISO and retry." "ERROR"
    throw "Citrix VM Tools installer not found. Mount the VM Tools ISO (Citrix Hypervisor Guest Tools)."
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Install Citrix VM Tools
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- [2] Installing Citrix VM Tools ---"
Write-Log "  Installer: $($installer.FullName)"
Write-Log "  Version:   $((Get-Item $installer.FullName).VersionInfo.FileVersion)"

$ext = $installer.Extension.ToLower()

try {
    if ($ext -eq ".exe") {
        # EXE installer (newer Citrix VM Tools format)
        $process = Start-Process -FilePath $installer.FullName `
            -ArgumentList "/quiet /norestart" `
            -Wait -PassThru -NoNewWindow
    }
    elseif ($ext -eq ".msi") {
        # MSI installer (older XenTools / management agent)
        $logPath = "C:\Windows\Temp\xentools-msi-install.log"
        $process = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/i `"$($installer.FullName)`" /quiet /norestart /log `"$logPath`"" `
            -Wait -PassThru -NoNewWindow
    }
    else {
        throw "Unknown installer format: $ext"
    }

    $exitCode = $process.ExitCode
    Write-Log "  Installer exit code: $exitCode"

    switch ($exitCode) {
        0    { Write-Log "  Citrix VM Tools installed successfully." }
        3010 { Write-Log "  Citrix VM Tools installed. Reboot required." }
        1641 { Write-Log "  Citrix VM Tools installed. Reboot initiated by installer." }
        default {
            Write-Log "  WARNING: Unexpected exit code $exitCode" "WARN"
        }
    }
}
catch {
    Write-Log "  Installation exception: $($_.Exception.Message)" "ERROR"
    throw
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Verify XenBus / XenNet drivers
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- [3] Verifying XenServer PV Drivers ---"

$expectedDrivers = @("xenvbd", "xennet", "xenbus", "xeniface")
foreach ($driver in $expectedDrivers) {
    $service = Get-Service -Name $driver -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "  Driver service present: $driver [Status: $($service.Status)]"
    } else {
        Write-Log "  Driver service NOT found: $driver (may require reboot to load)" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Configure XenServer Tools for MCS master image
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- [4] XenServer Tools - MCS Configuration ---"

# Disable automatic VM Tools update check (managed via new image in MCS)
$xenRegPath = "HKLM:\SOFTWARE\Citrix\XenTools"
if (Test-Path $xenRegPath) {
    Set-ItemProperty -Path $xenRegPath -Name "DisableAutoUpdate" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  Disabled XenTools auto-update."
}

# Enable memory ballooning (useful in XenServer MCS for efficient RAM use)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\xenfilt\Parameters" `
    -Name "EmulatedType" -Value "IDE" -Type String -ErrorAction SilentlyContinue

Write-Log "=== Citrix VM Tools (XenServer) Installation Complete ==="
Write-Log "Log: $LogFile"
Write-Log "Reboot required to fully load PV drivers."
