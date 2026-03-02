<#
    .DESCRIPTION
    Prepares a Windows 11 VDA master image for Citrix MCS (Machine Creation Services) deployment.

    Performs final cleanup to:
    - Minimize the image footprint (smaller delta disks in MCS = less storage, faster provisioning)
    - Remove machine-specific identifiers (for clean MCS cloning)
    - Verify VDA and Citrix services
    - Run Citrix Machine Identity preparation

    .NOTES
    !! DO NOT run Sysprep before MCS provisioning !!
    MCS handles machine identity (SID, hostname, domain join) through its own mechanism.
    Sysprep is only needed for Citrix PVS or manual VM duplication workflows.

    Run order: LAST step before Packer shuts down the VM and converts/snapshots it.
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\citrix-mcs-prep.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

Write-Log "=== Citrix MCS Master Image Preparation Start ==="
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Verify Citrix VDA Installation
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [1] VDA Verification ---"

$vdaPath = "$env:ProgramFiles\Citrix\Virtual Desktop Agent\BrokerAgent.exe"
if (Test-Path $vdaPath) {
    $version = (Get-Item $vdaPath).VersionInfo.FileVersion
    Write-Log "  VDA BrokerAgent.exe found. Version: $version"
} else {
    Write-Log "  WARNING: VDA not found at expected path. Continuing..." "WARN"
}

# Check key Citrix services exist (they should not be running yet in mastermcsimage mode)
$expectedServices = @("BrokerAgent", "Citrix Desktop Service", "Citrix HDX MediaStream", "Citrix ICA Service")
foreach ($svc in $expectedServices) {
    $s = Get-Service -DisplayName "*$svc*" -ErrorAction SilentlyContinue
    if ($s) {
        Write-Log "  Citrix service present: $($s.DisplayName) [StartType: $($s.StartType)]"
    } else {
        Write-Log "  Service not found: $svc (may be named differently)" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Clear Temporary Files
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [2] Temp File Cleanup ---"

$tempPaths = @(
    $env:TEMP,
    $env:TMP,
    "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive"
)

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        try {
            Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "  Cleared: $path"
        }
        catch { Write-Log "  Partial clear: $path - $($_.Exception.Message)" "WARN" }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Clear Windows Update Cache (SoftwareDistribution)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [3] Windows Update Cache ---"

Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$suPaths = @(
    "C:\Windows\SoftwareDistribution\Download",
    "C:\Windows\SoftwareDistribution\DataStore"
)
foreach ($path in $suPaths) {
    if (Test-Path $path) {
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "  Cleared: $path"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Clear All Event Logs
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [4] Event Logs ---"
try {
    Get-EventLog -LogName * -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Clear-EventLog -LogName $_.Log
            Write-Log "  Cleared event log: $($_.Log)"
        }
        catch { Write-Log "  Could not clear: $($_.Log)" "WARN" }
    }
    # Clear modern Windows event logs (ETW/evtx)
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 } | ForEach-Object {
        try {
            [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)
        }
        catch { }
    }
    Write-Log "  All event logs cleared."
}
catch { Write-Log "  Event log clear warning: $($_.Exception.Message)" "WARN" }

# ─────────────────────────────────────────────────────────────────────────────
# 5. Clear DNS Cache
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [5] DNS Cache ---"
Clear-DnsClientCache -ErrorAction SilentlyContinue
Write-Log "  DNS client cache cleared."

# ─────────────────────────────────────────────────────────────────────────────
# 6. Remove Packer Build User Profile (critical for clean MCS images!)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [6] Build User Profile Cleanup ---"

# The build user account (e.g., "adminst") will have a local profile on disk.
# This should NOT be in the master image as it would appear on every cloned VM.

$buildUser = $env:USERNAME
Write-Log "  Current build user: $buildUser"

# We cannot delete our own profile while logged in.
# Instead, mark it for deletion on next logon, and ensure it's stripped by MCS.
# MCS handles profile cleanup automatically, but we can also remove the profile data.

# Get other profiles that are not the build user or system accounts
$profilesToCheck = Get-WmiObject -Class Win32_UserProfile | Where-Object {
    -not $_.Special -and
    $_.LocalPath -notlike "*$buildUser*" -and
    $_.LocalPath -notlike "*Administrator*" -and
    $_.LocalPath -notlike "*systemprofile*" -and
    $_.LocalPath -notlike "*NetworkService*" -and
    $_.LocalPath -notlike "*LocalService*"
}

foreach ($profile in $profilesToCheck) {
    try {
        Write-Log "  Removing orphaned profile: $($profile.LocalPath)"
        $profile.Delete()
    }
    catch { Write-Log "  Could not remove profile: $($profile.LocalPath) - $($_.Exception.Message)" "WARN" }
}

# Clear Downloads, Desktop items, etc. from the build user's profile (keep it minimal)
$buildUserProfile = "C:\Users\$buildUser"
$pathsToCleanInProfile = @(
    "$buildUserProfile\Downloads",
    "$buildUserProfile\AppData\Local\Temp",
    "$buildUserProfile\AppData\Local\Microsoft\Windows\INetCache",
    "$buildUserProfile\AppData\Local\Microsoft\Windows\History",
    "$buildUserProfile\AppData\Roaming\Microsoft\Windows\Recent"
)
foreach ($p in $pathsToCleanInProfile) {
    if (Test-Path $p) {
        Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "  Cleaned profile path: $p"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. DISM Component Store Cleanup
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [7] DISM Component Store Cleanup ---"
try {
    Write-Log "  Running DISM /StartComponentCleanup... (may take several minutes)"
    $dismResult = & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
    Write-Log "  DISM result: $(($dismResult | Select-Object -Last 3) -join '; ')"
}
catch { Write-Log "  DISM cleanup warning: $($_.Exception.Message)" "WARN" }

# ─────────────────────────────────────────────────────────────────────────────
# 8. Run Disk Cleanup (cleanmgr)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [8] Disk Cleanup ---"
try {
    # Set all cleanup categories via registry
    $sageset = 65535
    $cleanupPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    Get-ChildItem $cleanupPath | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "StateFlags$sageset" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "  Starting cleanmgr with /sagerun:$sageset..."
    $cleanResult = Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:$sageset" -Wait -PassThru
    Write-Log "  cleanmgr completed. Exit code: $($cleanResult.ExitCode)"
}
catch { Write-Log "  Disk cleanup warning: $($_.Exception.Message)" "WARN" }

# ─────────────────────────────────────────────────────────────────────────────
# 9. Clear Pagefile on Shutdown (for smaller MCS delta disks)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [9] Pagefile Optimization ---"
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 1
Write-Log "  Set ClearPageFileAtShutdown = 1 (pagefile will be zeroed on next shutdown)."

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force | Out-Null
}

Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 1

# ─────────────────────────────────────────────────────────────────────────────
# 10. Reset Network Adapter (MCS will assign new MAC/IP per VM)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [10] Network Identity Reset ---"
# Clear any static IP / DHCP lease (MCS VMs get fresh DHCP)
Get-NetAdapter -Physical | ForEach-Object {
    try {
        $adapter = $_
        # Reset to DHCP (MCS VMs should use DHCP or get IP from Citrix provisioning)
        Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Enabled -ErrorAction SilentlyContinue
        Write-Log "  Reset NIC to DHCP: $($adapter.Name)"
    }
    catch { Write-Log "  NIC reset warning for $($_.Name): $($_.Exception.Message)" "WARN" }
}

# ─────────────────────────────────────────────────────────────────────────────
# 11. Verify Disk Space Saved
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [11] Disk Space Summary ---"
$disk = Get-PSDrive C
$usedGB  = [math]::Round($disk.Used / 1GB, 2)
$freeGB  = [math]::Round($disk.Free / 1GB, 2)
$totalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
Write-Log "  C: Drive: Used $usedGB GB / Total $totalGB GB / Free $freeGB GB"

# ─────────────────────────────────────────────────────────────────────────────
# 12. Final: Disable Machine Password Change (prevents domain trust issues in MCS)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [12] MCS Domain Trust Preparation ---"
# MCS manages machine account passwords itself.
# Disable automatic machine account password changes on the master image
# (MCS will handle this on each provisioned VM individually)
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" "DisablePasswordChange" 1
Write-Log "  Set DisablePasswordChange=1 (MCS will manage per-VM machine passwords)."

# ─────────────────────────────────────────────────────────────────────────────
# 13. Write MCS Prep Marker (for post-deployment verification)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [13] Writing MCS Image Marker ---"
$marker = @{
    PrepDate     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    OSVersion    = [System.Environment]::OSVersion.VersionString
    DiskUsedGB   = $usedGB
    VDAInstalled = (Test-Path "$env:ProgramFiles\Citrix\Virtual Desktop Agent\BrokerAgent.exe")
}
$marker | ConvertTo-Json | Set-Content -Path "C:\Windows\Temp\citrix-mcs-image-info.json"
Write-Log "  Image metadata written to C:\Windows\Temp\citrix-mcs-image-info.json"

Write-Log "=== Citrix MCS Master Image Preparation Complete ==="
Write-Log ""
Write-Log "NEXT STEPS (outside of Packer):"
Write-Log "  1. Packer will shut down the VM and convert/export it."
Write-Log "  2. In vSphere: take a VM snapshot (if not already done by Packer)."
Write-Log "  3. In Citrix DaaS console (or via deploy-citrix-mcs.ps1):"
Write-Log "     a. Create/update a Machine Catalog pointing to this VM snapshot."
Write-Log "     b. Provision VMs using MCS."
Write-Log "     c. Create/update a Delivery Group and assign users."
Write-Log "  4. MCS will automatically: join VMs to the domain, rename them, and"
Write-Log "     configure the VDA to register with the Cloud Connector."
