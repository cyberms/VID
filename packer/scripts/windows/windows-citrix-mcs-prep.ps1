<#
    .DESCRIPTION
    Prepares a Windows 11 VDA master image for Citrix MCS (Machine Creation Services) deployment.

    Performs final cleanup and optimisations:
      [1]  VDA Verification           – BrokerAgent.exe + Citrix services present
      [2]  Temp File Cleanup          – %TEMP%, Windows\Temp, Prefetch, WER
      [3]  Windows Update Cache       – SoftwareDistribution cleared
      [4]  Event Logs                 – all logs cleared
      [5]  DNS Cache                  – ipconfig /flushdns
      [6]  Build User Profile         – Downloads, cache, history
      [7]  DISM Component Cleanup     – /StartComponentCleanup
      [8]  Disk Cleanup               – cleanmgr /sagerun:65535
      [9]  Pagefile Optimisation      – broker-aware: citrix-mcs → D:\pagefile.sys;
                                        others → ClearPageFileAtShutdown=1 on C:
      [10] Disk Space Summary         – C: used/free logged
      [11] MCS Domain Trust Prep      – DisablePasswordChange=1 (MCS manages per-VM)
      [12] MCS Image Marker           – JSON written to C:\Windows\Temp\

    NIC reset is intentionally NOT performed: MCS assigns a new MAC address and IP
    to each provisioned VM automatically. Resetting the NIC in the master image would
    break the active WinRM session and cause Packer to abort the build.

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
# 9. Pagefile Optimization — broker-aware
#
#   Broker         | Strategy
#   ───────────────┼──────────────────────────────────────────────────────────
#   citrix-mcs     | The master image has C: (OS) + D: (Data, 10 GB).
#                  | D: was added by Packer (dynamic storage block) and
#                  | initialised by windows-init-data-disk.ps1 during the build.
#                  |
#                  | MCS DOES NOT clone D: from the master to provisioned VMs.
#                  | Instead, MCS IODriver attaches a fresh write-cache disk to
#                  | each new VM — this disk also receives the letter D:.
#                  |
#                  | This script stores the pagefile preference (D:\pagefile.sys,
#                  | system-managed size) in the master registry. Windows reads
#                  | this setting on first boot of each provisioned VM and creates
#                  | the actual pagefile on the MCS write-cache disk (D:).
#                  |
#                  | ClearPageFileAtShutdown = 0: the write-cache disk is
#                  | replaced per VM by MCS anyway — zeroing is not needed.
#                  | C: pagefile removed so all swap I/O goes to D:.
#                  |
#                  | ⚠ Fallback: if D: is absent (e.g. standalone boot from
#                  | the master snapshot without MCS), Windows falls back
#                  | automatically to a system-managed pagefile on C:.
#                  |
#   citrix-pvs     | ClearPageFileAtShutdown = 1 on C: (PVS streams the OS
#   avd            | disk; smaller deltas reduce network traffic on re-stream).
#   horizon        |
#   none           |
# ─────────────────────────────────────────────────────────────────────────────

$vidBroker = ($env:VID_BROKER -replace '"','').Trim().ToLower()
Write-Log "--- [9] Pagefile Optimization (VID_BROKER: $vidBroker) ---"

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force | Out-Null
}

$memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

if ($vidBroker -eq "citrix-mcs") {
    # Remove automatic pagefile management and set D: as preferred location.
    # MCS IODriver creates a fresh D: disk on each provisioned VM.
    Set-RegistryValue $memKey "ClearPageFileAtShutdown" 0
    # PagingFiles REG_MULTI_SZ: "drive:\pagefile.sys initialMB maximumMB"
    # Using 0 0 = system-managed size on D:; C: entry removed.
    Set-ItemProperty -Path $memKey -Name "PagingFiles" `
        -Value @("D:\pagefile.sys 0 0") -Type MultiString -Force
    Write-Log "  [citrix-mcs] Pagefile preference set to D:\pagefile.sys (system-managed size)."
    Write-Log "  [citrix-mcs] C: pagefile removed. MCS IODriver will initialise D: on first VM boot."
    Write-Log "  [citrix-mcs] ClearPageFileAtShutdown = 0 (D: is replaced per VM by MCS; zeroing not needed)."
} else {
    # All other brokers: keep pagefile on C:, zero it on shutdown to minimise
    # delta disk size (PVS network blocks, AVD managed-disk snapshots, etc.).
    Set-RegistryValue $memKey "ClearPageFileAtShutdown" 1
    Write-Log "  [$vidBroker] ClearPageFileAtShutdown = 1 (pagefile zeroed on shutdown for smaller deltas)."
}

# ─────────────────────────────────────────────────────────────────────────────
# 10. Verify Disk Space Saved
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: No NIC reset needed for MCS. MCS assigns a new MAC address and IP to
# each provisioned VM automatically. Resetting the NIC in the master image
# would break the active WinRM session and cause Packer to abort.

Write-Log "--- [10] Disk Space Summary ---"
$disk = Get-PSDrive C
$usedGB  = [math]::Round($disk.Used / 1GB, 2)
$freeGB  = [math]::Round($disk.Free / 1GB, 2)
$totalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
Write-Log "  C: Drive: Used $usedGB GB / Total $totalGB GB / Free $freeGB GB"

# ─────────────────────────────────────────────────────────────────────────────
# 11. Final: Disable Machine Password Change (prevents domain trust issues in MCS)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [11] MCS Domain Trust Preparation ---"
# MCS manages machine account passwords itself.
# Disable automatic machine account password changes on the master image
# (MCS will handle this on each provisioned VM individually)
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" "DisablePasswordChange" 1
Write-Log "  Set DisablePasswordChange=1 (MCS will manage per-VM machine passwords)."

# ─────────────────────────────────────────────────────────────────────────────
# 12. Write MCS Prep Marker (for post-deployment verification)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [12] Writing MCS Image Marker ---"
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
