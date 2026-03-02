<#
    .DESCRIPTION
    Applies Citrix and Windows 11 best-practice optimizations for VDI/MCS deployments.
    Based on Citrix Optimizer recommendations and Citrix CTX216252 hardening guide.

    .NOTES
    Covers:
    - Windows 11 VDI tuning (services, scheduled tasks, features)
    - Citrix-specific registry tweaks
    - Power plan, page file, network, and storage settings
    - AppX bloatware removal
    - Security baseline adjustments for VDI

    IMPORTANT: Review each section against your organization's security policy
    before applying in production.
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\citrix-optimize.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force | Out-Null
        Write-Log "  REG SET: $Path\$Name = $Value"
    }
    catch {
        Write-Log "  REG FAIL: $Path\$Name - $($_.Exception.Message)" "WARN"
    }
}

function Disable-ServiceSafely {
    param([string]$ServiceName, [string]$Reason)
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Set-Service -Name $ServiceName -StartupType Disabled
            Write-Log "  DISABLED service: $ServiceName ($Reason)"
        } else {
            Write-Log "  SKIP (not found): $ServiceName" "WARN"
        }
    }
    catch {
        Write-Log "  FAIL disabling $ServiceName`: $($_.Exception.Message)" "WARN"
    }
}

function Disable-ScheduledTaskSafely {
    param([string]$TaskPath, [string]$TaskName)
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null
            Write-Log "  DISABLED task: $TaskPath$TaskName"
        }
    }
    catch {
        Write-Log "  FAIL disabling task $TaskPath$TaskName`: $($_.Exception.Message)" "WARN"
    }
}

Write-Log "=== Citrix VDI Optimization Start ==="
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Power Plan: High Performance (mandatory for VDI)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [1] Power Plan ---"
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg.exe /setactive $highPerfGuid
powercfg.exe /change standby-timeout-ac 0
powercfg.exe /change hibernate-timeout-ac 0
powercfg.exe /change monitor-timeout-ac 0
powercfg.exe /change disk-timeout-ac 0
Write-Log "  Power plan set to High Performance, all timeouts disabled."

# Disable Fast Startup (causes issues with VMs and domain rejoining)
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0

# ─────────────────────────────────────────────────────────────────────────────
# 2. Virtual Memory / Page File (MCS manages this per-VM)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [2] Page File ---"
# Set automatic page file management (MCS will inherit this setting)
$cs = Get-WmiObject -Class Win32_ComputerSystem
$cs.AutomaticManagedPagefile = $true
$cs.Put() | Out-Null
Write-Log "  Page file set to system-managed (automatic)."

# ─────────────────────────────────────────────────────────────────────────────
# 3. Disable Unnecessary Windows Services
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [3] Services ---"

# Telemetry / Diagnostics
Disable-ServiceSafely "DiagTrack"           "Windows Connected User Experiences and Telemetry"
Disable-ServiceSafely "dmwappushservice"    "WAP Push Message Routing Service (telemetry)"
Disable-ServiceSafely "PcaSvc"             "Program Compatibility Assistant"
Disable-ServiceSafely "WerSvc"             "Windows Error Reporting Service"
Disable-ServiceSafely "wercplsupport"      "Problem Reports Control Panel Support"

# Search / Indexing (not useful in non-persistent VDI)
Disable-ServiceSafely "WSearch"            "Windows Search (indexing not useful in non-persistent VDI)"

# SysMain / Superfetch (not useful for VMs, causes I/O storms)
Disable-ServiceSafely "SysMain"            "Superfetch/SysMain (causes I/O storms in VDI)"

# Connected Devices / Bluetooth (not present in VMs)
Disable-ServiceSafely "CDPSvc"             "Connected Devices Platform Service"
Disable-ServiceSafely "CDPUserSvc"         "Connected Devices Platform User Service"
Disable-ServiceSafely "BluetoothUserService" "Bluetooth User Support Service"
Disable-ServiceSafely "bthserv"            "Bluetooth Support Service"

# Retail demo / consumer features
Disable-ServiceSafely "RetailDemo"         "Retail Demo Service"
Disable-ServiceSafely "MapsBroker"         "Downloaded Maps Manager"

# Xbox / Gaming (not needed in VDI)
Disable-ServiceSafely "XblAuthManager"     "Xbox Live Auth Manager"
Disable-ServiceSafely "XblGameSave"        "Xbox Live Game Save"
Disable-ServiceSafely "XboxGipSvc"         "Xbox Accessory Management Service"
Disable-ServiceSafely "XboxNetApiSvc"      "Xbox Live Networking Service"

# Mixed Reality / Spatial Audio
Disable-ServiceSafely "SpatialDataService" "Spatial Data Service"
Disable-ServiceSafely "spectrum"           "Windows Perception Service"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Disable Unnecessary Scheduled Tasks
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [4] Scheduled Tasks ---"

Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "Microsoft Compatibility Appraiser"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "ProgramDataUpdater"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "StartupAppTask"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Autochk\"               "Proxy"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Customer Experience Improvement Program\" "Consolidator"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Customer Experience Improvement Program\" "UsbCeip"
Disable-ScheduledTaskSafely "\Microsoft\Windows\DiskDiagnostic\"        "Microsoft-Windows-DiskDiagnosticDataCollector"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Feedback\Siuf\"         "DmClient"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Feedback\Siuf\"         "DmClientOnScenarioDownload"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Maps\"                  "MapsToastTask"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Maps\"                  "MapsUpdateTask"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Mobile Broadband Accounts\" "MNO Metadata Parser"
Disable-ScheduledTaskSafely "\Microsoft\Windows\NetTrace\"              "GatherNetworkInfo"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Power Efficiency Diagnostics\" "AnalyzeSystem"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Shell\"                 "FamilySafetyMonitor"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Shell\"                 "FamilySafetyRefreshTask"
Disable-ScheduledTaskSafely "\Microsoft\Windows\WaaSMedic\"             "PerformRemediation"
Disable-ScheduledTaskSafely "\Microsoft\Windows\WindowsUpdate\"         "Scheduled Start"
Disable-ScheduledTaskSafely "\Microsoft\Windows\WindowsUpdate\"         "sih"
Disable-ScheduledTaskSafely "\Microsoft\Windows\WindowsUpdate\"         "sihboot"
Disable-ScheduledTaskSafely "\Microsoft\XblGameSave\"                   "XblGameSaveTask"

# ─────────────────────────────────────────────────────────────────────────────
# 5. Windows Update Policy (new images replace updates in MCS)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [5] Windows Update (disable auto-update in VDI) ---"
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
Set-RegistryValue $wuPath "NoAutoUpdate"           1
Set-RegistryValue $wuPath "AUOptions"              1      # Never auto-download or auto-install
Set-RegistryValue $wuPath "UseWUServer"            0

# Disable Windows Update delivery optimization (peer-to-peer bandwidth waste)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0

# ─────────────────────────────────────────────────────────────────────────────
# 6. Telemetry, Privacy, and Consumer Features
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [6] Telemetry & Privacy ---"

# Disable Windows Telemetry
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0

# Disable advertising ID
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1

# Disable Cortana
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "CortanaConsent" 0

# Disable Consumer Features (app suggestions, automatic app install)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1

# Disable Windows Feedback
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1

# Disable Activity History
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0

# Disable Remote Assistance
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "fAllowToGetHelp" 0

# ─────────────────────────────────────────────────────────────────────────────
# 7. OneDrive (disable sync in VDI)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [7] OneDrive ---"
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSync" 1

# Optionally uninstall OneDrive (comment out if your org uses OneDrive)
$oneDriveExe = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
if (Test-Path $oneDriveExe) {
    Write-Log "  Uninstalling OneDrive..."
    Start-Process $oneDriveExe -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
    Write-Log "  OneDrive uninstalled."
}

# ─────────────────────────────────────────────────────────────────────────────
# 8. Network Optimizations
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [8] Network Optimizations ---"

# Disable NIC power management (prevent adapter sleep in VMs)
Get-NetAdapter -Physical | ForEach-Object {
    try {
        $adapter = $_
        $powerMgmt = Get-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
        if ($powerMgmt) {
            Set-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket Disabled -WakeOnPattern Disabled -ErrorAction SilentlyContinue
            Write-Log "  Disabled power management for NIC: $($adapter.Name)"
        }
    }
    catch { Write-Log "  Could not configure power management for $($adapter.Name)" "WARN" }
}

# Disable Large Send Offload (LSO) – can cause issues with Citrix HDX
Get-NetAdapter -Physical | ForEach-Object {
    Disable-NetAdapterLso -Name $_.Name -ErrorAction SilentlyContinue
    Write-Log "  Disabled LSO on: $($_.Name)"
}

# Optimize TCP for LAN (not WAN) – Citrix HDX handles WAN optimization
Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Normal -ErrorAction SilentlyContinue

# DNS Client settings
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxCacheTtl" 300
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "NegativeCacheTime" 30

# ─────────────────────────────────────────────────────────────────────────────
# 9. Storage / Filesystem Optimizations
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [9] Storage / Filesystem ---"

# Disable 8.3 filename generation (performance boost for NTFS)
fsutil behavior set disable8dot3 1 | Out-Null
Write-Log "  Disabled 8.3 filename generation."

# Disable last access timestamp (significant IOPS reduction)
fsutil behavior set disablelastaccess 1 | Out-Null
Write-Log "  Disabled last access timestamp."

# Disable SuperFetch prefetching (not useful on SAN/NFS storage)
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableBootTrace" 0

# ─────────────────────────────────────────────────────────────────────────────
# 10. Windows Security / Defender (balance security and VDI performance)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [10] Windows Defender / Security ---"

# Exclude Citrix VDA directories from Defender scanning (performance)
$defenderExclusions = @(
    "$env:ProgramFiles\Citrix",
    "$env:ProgramData\Citrix",
    "C:\Windows\Temp\Citrix*"
)
foreach ($exclusion in $defenderExclusions) {
    Add-MpPreference -ExclusionPath $exclusion -ErrorAction SilentlyContinue
    Write-Log "  Added Defender exclusion: $exclusion"
}

# Disable real-time scanning of network shares (Citrix profile containers etc.)
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue  # Keep RT enabled for security
Set-MpPreference -ScanNetworkFiles $false -ErrorAction SilentlyContinue
Write-Log "  Disabled Defender scanning of network files."

# Disable Windows SmartScreen in managed enterprise environment
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "Off" -Type "String"

# ─────────────────────────────────────────────────────────────────────────────
# 11. Citrix-Specific Registry Optimizations
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [11] Citrix-Specific Registry Tweaks ---"

# VDA latency/performance
Set-RegistryValue "HKLM:\SOFTWARE\Citrix\CtxHook\AppInit_DLLs\SwitchHook" "ExcludedImageNames" "" -Type "String"

# Enable EDT (Enlightened Data Transport) - already enabled via /enable_real_time_transport
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Citrix\ICA Client\Engine\Lockdown Profiles\All Regions\Lockdown\Network\UDT" "UDTProtocol" "true" -Type "String"

# Citrix MultiStream (QoS for ICA sessions - optional, requires switch config)
# Set-RegistryValue "HKLM:\SOFTWARE\Policies\Citrix" "MultiStreamPolicy" 1

# HDX 3D Pro / GPU (disable if no GPU/vGPU in MCS catalog)
# Set-RegistryValue "HKLM:\SOFTWARE\Citrix\Graphics" "UseHardwareEncoding" 0

# Desktop composition for smooth user experience
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" "DisallowFlip3d" 0

# ─────────────────────────────────────────────────────────────────────────────
# 12. Visual / UI Optimizations (VDI performance without sacrificing usability)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [12] Visual / UI Optimizations ---"

# Reduce animations (less CPU/GPU in virtual sessions)
$visualPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
Set-RegistryValue $visualPath "VisualFXSetting" 2  # 2 = Custom, best performance without being ugly

$advancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-RegistryValue $advancedPath "ListviewAlphaSelect"  0
Set-RegistryValue $advancedPath "ListviewShadow"       0
Set-RegistryValue $advancedPath "TaskbarAnimations"    0

# Disable transparency effects
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "EnableAeroPeek" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

# Disable background apps
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2  # Force deny

# ─────────────────────────────────────────────────────────────────────────────
# 13. Remove Windows AppX Bloatware (per-user provisioned apps not needed in VDI)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [13] AppX Bloatware Removal ---"

$appsToRemove = @(
    "Microsoft.BingFinance",
    "Microsoft.BingNews",
    "Microsoft.BingSports",
    "Microsoft.BingWeather",
    "Microsoft.GamingApp",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal",
    "Microsoft.MSPaint",          # Keep if users need Paint
    "Microsoft.Office.OneNote",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.SkypeApp",
    "Microsoft.Todos",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

foreach ($app in $appsToRemove) {
    # Remove provisioned (all users) package
    $provPkg = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$app*"
    if ($provPkg) {
        Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction SilentlyContinue | Out-Null
        Write-Log "  Removed provisioned package: $app"
    }
    # Remove installed package for all users
    Get-AppxPackage -AllUsers -Name "*$app*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
# 14. Event Log Sizing (for VDI environments, increase log sizes)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [14] Event Log Sizes ---"
$logConfigs = @{
    "System"      = 50MB
    "Application" = 50MB
    "Security"    = 100MB
}
foreach ($log in $logConfigs.GetEnumerator()) {
    limit-eventlog -LogName $log.Key -MaximumSize $log.Value -ErrorAction SilentlyContinue
    Write-Log "  Set $($log.Key) log max size to $([math]::Round($log.Value/1MB))MB"
}

# ─────────────────────────────────────────────────────────────────────────────
# 15. Windows Error Reporting
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [15] Windows Error Reporting ---"
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1

# ─────────────────────────────────────────────────────────────────────────────
# 16. Locale / Regional Settings (German keyboard, EU time, English interface)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [16] Regional Settings ---"
Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction SilentlyContinue
Write-Log "  Timezone set to W. Europe Standard Time (CET/CEST)"

# ─────────────────────────────────────────────────────────────────────────────
# 17. Terminal Services / RDP Tuning for Citrix coexistence
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [17] RDP/Terminal Services ---"
# Limit RDP sessions (Citrix manages session brokering, not Windows RDP)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "MaxConnectionTime" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "MaxDisconnectionTime" 0
# Keep color depth at 32-bit for Citrix HDX (not 16-bit)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "ColorDepth" 4  # 4 = 32-bit

# ─────────────────────────────────────────────────────────────────────────────
# 18. Startup Programs / Shell
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [18] Startup Cleanup ---"

# Disable Microsoft Teams auto-start (if Teams Machine-Wide Installer present)
$teamsAutoStartPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
Remove-ItemProperty -Path $teamsAutoStartPath -Name "com.squirrel.Teams.Teams" -ErrorAction SilentlyContinue
Write-Log "  Removed Teams auto-start from Run key."

# Disable OneDrive startup
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue

# Disable Search highlights in taskbar
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0

Write-Log "=== Citrix VDI Optimization Complete ==="
Write-Log "Log: $LogFile"
