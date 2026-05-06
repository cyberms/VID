<#
.SYNOPSIS
    VID Layer 7b – Broker-agnostische Windows VDI Optimierungen

.DESCRIPTION
    Wendet allgemeine Windows 11 VDI-Optimierungen an, die für ALLE Broker gelten
    (Citrix, Horizon, AVD, none).

    Broker-spezifische Optimierungen erfolgen DANACH in separaten Scripts:
      - windows-citrix-optimize.ps1  (Layer 7b – Citrix-spezifisch)
      - windows-horizon-optimize.ps1 (Layer 7b – Horizon-spezifisch)
      [AVD: keine zusätzlichen Broker-Tweaks erforderlich]

    Inhalt:
      [1]  Power Plan – High Performance, alle Timeouts deaktiviert
      [2]  Page File – system-managed (WMI mit Registry-Fallback)
      [3]  Services – Telemetrie, SysMain, WSearch, Xbox, Bluetooth, Mobile, Sync, ...
      [3b] WMI Autologger – Boot-Tracing-Sitzungen deaktivieren
      [4]  Scheduled Tasks – Diagnostics, CEIP, WU, Xbox, Location, DiskCleanup, ...
      [5]  Windows Update – Auto-Update und Delivery Optimization deaktiviert
      [6]  Telemetrie & Datenschutz – Cortana, ActivityHistory, AdvertisingID, ...
      [7]  OneDrive – deaktiviert / deinstalliert
      [8]  Netzwerk – NIC Power Mgmt, LSO, TCP Tuning, DNS Cache
      [9]  Storage/Filesystem – 8.3 Namen, Last Access Timestamp, Prefetch
      [10] Windows Defender / SmartScreen – SmartScreen deaktiviert
      [11] Visual/UI – Animationen, Transparenz, Hintergrund-Apps
      [12] AppX Bloatware – Entfernung vorinstallierter Consumer-Apps
      [13] Event Log – Maximale Log-Größen erhöhen
      [14] Windows Error Reporting – deaktiviert
      [15] Regionale Einstellungen – Zeitzone
      [16] Terminal Services – Session-Limits, Color Depth (für VDI)
      [17] Startup Cleanup – Teams, OneDrive, Search Highlights

.NOTES
    VID Layer  : 7b – Generic VDI Optimizations (broker-agnostic)
    Broker     : ALL (citrix-mcs, citrix-pvs, horizon, avd, none)
    Maintainer : VID-Team
    Basis      : Citrix CTX216252, Microsoft VDI Best Practices, Horizon Optimization Guide
    Created    : 2026-05-05
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$logDir  = "C:\Windows\Logs\VID"
$logFile = "$logDir\vid-vdi-optimize.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-VIDLog {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force | Out-Null
        Write-VIDLog "  REG SET: $Path\$Name = $Value"
    }
    catch {
        Write-VIDLog "  REG FAIL: $Path\$Name - $($_.Exception.Message)" "WARN"
    }
}

function Disable-ServiceSafely {
    param([string]$ServiceName, [string]$Reason)
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service  -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Set-Service   -Name $ServiceName -StartupType Disabled
            Write-VIDLog "  DISABLED service: $ServiceName ($Reason)"
        } else {
            Write-VIDLog "  SKIP (not found): $ServiceName" "WARN"
        }
    }
    catch { Write-VIDLog "  FAIL disabling $ServiceName: $($_.Exception.Message)" "WARN" }
}

function Disable-ScheduledTaskSafely {
    param([string]$TaskPath, [string]$TaskName)
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null
            Write-VIDLog "  DISABLED task: $TaskPath$TaskName"
        }
    }
    catch { Write-VIDLog "  FAIL disabling task $TaskPath$TaskName: $($_.Exception.Message)" "WARN" }
}

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – Generic VDI Optimization Start"
Write-VIDLog "Broker: $env:VID_BROKER"
Write-VIDLog "OS: $([System.Environment]::OSVersion.VersionString)"
Write-VIDLog "═══════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# [1] Power Plan: High Performance (mandatory for VDI)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [1] Power Plan ---"
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg.exe /setactive $highPerfGuid
powercfg.exe /change standby-timeout-ac 0
powercfg.exe /change hibernate-timeout-ac 0
powercfg.exe /change monitor-timeout-ac 0
powercfg.exe /change disk-timeout-ac 0
Write-VIDLog "  Power plan set to High Performance, all timeouts disabled."

# Disable Fast Startup (causes issues with VMs and domain re-joining)
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0

# ─────────────────────────────────────────────────────────────────────────────
# [2] Virtual Memory / Page File (Image-Management manages this per-VM)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [2] Page File ---"
# Set automatic page file management; WMI Put() can fail in WinRM context,
# so fall back to registry if needed.
try {
    $cs = Get-WmiObject -Class Win32_ComputerSystem
    $cs.AutomaticManagedPagefile = $true
    $cs.Put() | Out-Null
    Write-VIDLog "  Page file set to system-managed (WMI)."
}
catch {
    Write-VIDLog "  WMI Put() failed: $($_.Exception.Message) – using registry fallback." "WARN"
    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
        -Name "AutomaticManagedPageFile" -Value 1 -Type DWord -Force
    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
        -Name "PagingFiles" -Value @() -Type MultiString -Force
    Write-VIDLog "  Page file set to system-managed (registry fallback)."
}

# ─────────────────────────────────────────────────────────────────────────────
# [3] Disable Unnecessary Windows Services
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [3] Services ---"

# Telemetry / Diagnostics
Disable-ServiceSafely "DiagTrack"             "Windows Connected User Experiences and Telemetry"
Disable-ServiceSafely "dmwappushservice"      "WAP Push Message Routing Service (telemetry)"
Disable-ServiceSafely "PcaSvc"               "Program Compatibility Assistant"
Disable-ServiceSafely "WerSvc"               "Windows Error Reporting Service"
Disable-ServiceSafely "wercplsupport"        "Problem Reports Control Panel Support"

# Search / Indexing (not useful in non-persistent VDI)
Disable-ServiceSafely "WSearch"              "Windows Search (indexing not useful in non-persistent VDI)"

# SysMain / Superfetch (causes I/O storms in VDI environments)
Disable-ServiceSafely "SysMain"              "Superfetch/SysMain (causes I/O storms in VDI)"

# Connected Devices / Bluetooth (not present in VMs)
Disable-ServiceSafely "CDPSvc"               "Connected Devices Platform Service"
Disable-ServiceSafely "CDPUserSvc"           "Connected Devices Platform User Service"
Disable-ServiceSafely "BluetoothUserService" "Bluetooth User Support Service"
Disable-ServiceSafely "bthserv"              "Bluetooth Support Service"

# Retail demo / consumer features
Disable-ServiceSafely "RetailDemo"           "Retail Demo Service"
Disable-ServiceSafely "MapsBroker"           "Downloaded Maps Manager"

# Xbox / Gaming (not needed in VDI)
Disable-ServiceSafely "XblAuthManager"       "Xbox Live Auth Manager"
Disable-ServiceSafely "XblGameSave"          "Xbox Live Game Save"
Disable-ServiceSafely "XboxGipSvc"           "Xbox Accessory Management Service"
Disable-ServiceSafely "XboxNetApiSvc"        "Xbox Live Networking Service"

# Mixed Reality / Spatial Audio
Disable-ServiceSafely "SpatialDataService"   "Spatial Data Service"
Disable-ServiceSafely "spectrum"             "Windows Perception Service"

# Mobile / Hotspot / Location (nicht relevant in VDI)
Disable-ServiceSafely "icssvc"               "Windows Mobile Hotspot Service"
Disable-ServiceSafely "lfsvc"                "Geolocation Service"
Disable-ServiceSafely "autotimesvc"          "Cellular Time (Auto Time Zone Updater)"

# Data Sync / Messaging / Wallet (Consumer-Features)
Disable-ServiceSafely "OneSyncSvc"           "Sync Host (OneDrive Sync etc.)"
Disable-ServiceSafely "MessagingService"     "Messaging Service"
Disable-ServiceSafely "WalletService"        "WalletService"
Disable-ServiceSafely "PimIndexMaintenanceSvc" "Contact Data / PIM Index"
Disable-ServiceSafely "TabletInputService"   "Touch Keyboard and Handwriting Panel"

# Device / Hardware (nicht vorhanden in VMs)
Disable-ServiceSafely "WbioSrvc"             "Windows Biometric Service (kein Fingerprint in VMs)"
Disable-ServiceSafely "SCardSvr"             "Smart Card Service"
Disable-ServiceSafely "DsmSvc"               "Device Setup Manager"
Disable-ServiceSafely "DusmSvc"              "Data Usage Service"
Disable-ServiceSafely "SSDPSRV"              "SSDP Discovery (UPnP)"

# Network Sharing / Printing (nicht benötigt in nicht-persistenten VDI)
Disable-ServiceSafely "WMPNetworkSvc"        "Windows Media Player Network Sharing"
Disable-ServiceSafely "Spooler"              "Print Spooler (kein lokaler Drucker in VDI)"

# Offline Files (nicht sinnvoll in nicht-persistenten VMs)
Disable-ServiceSafely "CscService"           "Offline Files (Client-Side Caching)"

# Windows Insider
Disable-ServiceSafely "wisvc"                "Windows Insider Service"

# ─────────────────────────────────────────────────────────────────────────────
# [3b] WMI Autologger – Tracing-Sitzungen beim Boot deaktivieren
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [3b] WMI Autologger ---"

$autologgers = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AppModel",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CloudExperienceHostOOBE",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WDIContextLog",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverIHVSession",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiSession",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Cellcore",
    "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WinPhoneCritical"
)
foreach ($al in $autologgers) {
    try {
        if (Test-Path $al) {
            Set-ItemProperty -Path $al -Name "Start" -Value 0 -Type DWord -Force | Out-Null
            Write-VIDLog "  Autologger deaktiviert: $(Split-Path $al -Leaf)"
        }
    }
    catch { Write-VIDLog "  Autologger FAIL: $(Split-Path $al -Leaf) – $($_.Exception.Message)" "WARN" }
}

# ─────────────────────────────────────────────────────────────────────────────
# [4] Disable Unnecessary Scheduled Tasks
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [4] Scheduled Tasks ---"

Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "Microsoft Compatibility Appraiser"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "PcaPatchDbTask"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "ProgramDataUpdater"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Application Experience\" "StartupAppTask"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Autochk\"               "Proxy"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Customer Experience Improvement Program\" "Consolidator"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Customer Experience Improvement Program\" "UsbCeip"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Device Information\"    "Device"
Disable-ScheduledTaskSafely "\Microsoft\Windows\DiskCleanup\"           "SilentCleanup"
Disable-ScheduledTaskSafely "\Microsoft\Windows\DiskDiagnostic\"        "Microsoft-Windows-DiskDiagnosticDataCollector"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Location\"              "Notifications"
Disable-ScheduledTaskSafely "\Microsoft\Windows\Location\"              "WindowsActionDialog"
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
# [5] Windows Update Policy (neues Image = neue Patches – kein Auto-Update nötig)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [5] Windows Update (disable auto-update in VDI) ---"
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
Set-RegistryValue $wuPath "NoAutoUpdate"              1
Set-RegistryValue $wuPath "AUOptions"               1    # Never auto-download or auto-install
Set-RegistryValue $wuPath "UseWUServer"             0
Set-RegistryValue $wuPath "NoAutoRebootWithLoggedOnUsers" 1  # Kein Zwangs-Reboot bei aktiven Sitzungen

# Disable delivery optimization (P2P bandwidth waste in VDI)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0

# ─────────────────────────────────────────────────────────────────────────────
# [6] Telemetry, Privacy, and Consumer Features
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [6] Telemetrie & Datenschutz ---"

Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"     "AllowTelemetry"              0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled"                 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"    "DisabledByGroupPolicy"       1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"     "AllowCortana"               0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"     "CortanaConsent"             0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"       "DisableWindowsConsumerFeatures" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"       "DisableSoftLanding"          1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"            "AllowGameDVR"                0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"     "DoNotShowFeedbackNotifications" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"             "EnableActivityFeed"          0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"             "PublishUserActivities"       0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"             "UploadUserActivities"        0
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"     "fAllowToGetHelp"             0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "fAllowToGetHelp"           0

# ─────────────────────────────────────────────────────────────────────────────
# [7] OneDrive (FSLogix / UPM übernimmt Profile – OneDrive in VDI nicht sinnvoll)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [7] OneDrive ---"
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSync"     1

$oneDriveExe = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
if (Test-Path $oneDriveExe) {
    Write-VIDLog "  Deinstalliere OneDrive..."
    Start-Process $oneDriveExe -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
    Write-VIDLog "  OneDrive deinstalliert."
}

# ─────────────────────────────────────────────────────────────────────────────
# [8] Netzwerk-Optimierungen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [8] Netzwerk-Optimierungen ---"

# NIC Power Management deaktivieren (verhindert Adapter-Sleep in VMs)
Get-NetAdapter -Physical | ForEach-Object {
    try {
        $pm = Get-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
        if ($pm) {
            Set-NetAdapterPowerManagement -Name $_.Name `
                -WakeOnMagicPacket Disabled -WakeOnPattern Disabled `
                -ErrorAction SilentlyContinue
            Write-VIDLog "  NIC Power Mgmt deaktiviert: $($_.Name)"
        }
    }
    catch { Write-VIDLog "  NIC Power Mgmt konnte nicht konfiguriert werden: $($_.Name)" "WARN" }
}

# LSO (Large Send Offload) deaktivieren – kann zu Paketverlusten in virtuellen Switches führen
Get-NetAdapter -Physical | ForEach-Object {
    Disable-NetAdapterLso -Name $_.Name -ErrorAction SilentlyContinue
    Write-VIDLog "  LSO deaktiviert: $($_.Name)"
}

# TCP Auto-Tuning für LAN-Umgebung (Datacenter/VDI-Netzwerk)
Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Normal -ErrorAction SilentlyContinue

# DNS-Cache TTL begrenzen (für schnellere Namensauflösung nach Änderungen)
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxCacheTtl"     300
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "NegativeCacheTime" 30

# Multimedia Scheduling – Netzwerk-Priorisierung und System-Reaktionsfähigkeit für VDI
$mmProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-RegistryValue $mmProfile "NetworkThrottlingIndex" 4294967295  # Deaktiviert Netzwerk-Throttling für Multimedia
Set-RegistryValue $mmProfile "SystemResponsiveness"  0           # Maximale Reaktionsfähigkeit für Vordergrund-Prozesse

# ─────────────────────────────────────────────────────────────────────────────
# [9] Storage / Filesystem Optimierungen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [9] Storage / Filesystem ---"

fsutil behavior set disable8dot3 1 | Out-Null
Write-VIDLog "  8.3 Dateinamen-Generierung deaktiviert."

fsutil behavior set disablelastaccess 1 | Out-Null
Write-VIDLog "  Last-Access Timestamp deaktiviert."

Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableBootTrace"  0

# ─────────────────────────────────────────────────────────────────────────────
# [10] Windows Defender / SmartScreen (Basis-Konfiguration für verwaltete VDI-Umgebung)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [10] Windows Defender / SmartScreen ---"

# Defender: Netzwerkdateien nicht scannen (Performance bei Profil-Containern)
Set-MpPreference -ScanNetworkFiles $false -ErrorAction SilentlyContinue
Write-VIDLog "  Defender: ScanNetworkFiles deaktiviert."

# SmartScreen deaktivieren (in zentral verwalteten Enterprise-Umgebungen per GPO)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "Off" -Type "String"

# ─────────────────────────────────────────────────────────────────────────────
# [11] Visual / UI Optimierungen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [11] Visual / UI ---"

$visualPath   = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$advancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

Set-RegistryValue $visualPath   "VisualFXSetting"       2   # Custom (Beste Leistung ohne ganz nacktes UI)
Set-RegistryValue $advancedPath "ListviewAlphaSelect"   0
Set-RegistryValue $advancedPath "ListviewShadow"        0
Set-RegistryValue $advancedPath "TaskbarAnimations"     0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"                                     "EnableAeroPeek"      0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"       "EnableTransparency"  0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                     "LetAppsRunInBackground" 2

# ─────────────────────────────────────────────────────────────────────────────
# [12] AppX Bloatware entfernen (Consumer-Apps unnötig in VDI)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [12] AppX Bloatware ---"

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
    "Microsoft.MSPaint",
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
    $provPkg = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$app*"
    if ($provPkg) {
        Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction SilentlyContinue | Out-Null
        Write-VIDLog "  Provisioned package entfernt: $app"
    }
    Get-AppxPackage -AllUsers -Name "*$app*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
# [13] Event Log Größen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [13] Event Log Größen ---"
$logConfigs = @{
    "System"      = 50MB
    "Application" = 50MB
    "Security"    = 100MB
}
foreach ($log in $logConfigs.GetEnumerator()) {
    Limit-EventLog -LogName $log.Key -MaximumSize $log.Value -ErrorAction SilentlyContinue
    Write-VIDLog "  $($log.Key) Log-Größe: $([math]::Round($log.Value/1MB)) MB"
}

# ─────────────────────────────────────────────────────────────────────────────
# [14] Windows Error Reporting deaktivieren
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [14] Windows Error Reporting ---"
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1

# ─────────────────────────────────────────────────────────────────────────────
# [15] Regionale Einstellungen
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [15] Regionale Einstellungen ---"
Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction SilentlyContinue
Write-VIDLog "  Zeitzone: W. Europe Standard Time (CET/CEST)"

# ─────────────────────────────────────────────────────────────────────────────
# [16] Terminal Services / RDP (generische VDI-Einstellungen)
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [16] Terminal Services / RDP ---"
$tsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
Set-RegistryValue $tsPath "MaxConnectionTime"    0   # Kein Verbindungs-Timeout
Set-RegistryValue $tsPath "MaxDisconnectionTime" 0   # Kein Disconnect-Timeout
Set-RegistryValue $tsPath "ColorDepth"           4   # 32-bit Farbtiefe

# ─────────────────────────────────────────────────────────────────────────────
# [17] Startup Cleanup
# ─────────────────────────────────────────────────────────────────────────────

Write-VIDLog "--- [17] Startup Cleanup ---"

Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "com.squirrel.Teams.Teams" -ErrorAction SilentlyContinue
Write-VIDLog "  Teams Autostart entfernt."

Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
Write-VIDLog "  OneDrive Autostart entfernt."

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0

# ─────────────────────────────────────────────────────────────────────────────
# VID Registry – Sentinel
# ─────────────────────────────────────────────────────────────────────────────

$sentinelKey = "HKLM:\SOFTWARE\VendorIndependenceDay\Optimization"
New-Item -Path $sentinelKey -Force | Out-Null
Set-ItemProperty -Path $sentinelKey -Name "VDIOptimizeApplied"   -Value "Applied"
Set-ItemProperty -Path $sentinelKey -Name "VDIOptimizeTimestamp" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Set-ItemProperty -Path $sentinelKey -Name "VDIOptimizeBroker"    -Value ($env:VID_BROKER ?? "unknown")

Write-VIDLog "═══════════════════════════════════════════════"
Write-VIDLog "VID Layer 7b – Generic VDI Optimization abgeschlossen."
Write-VIDLog "Log: $logFile"
Write-VIDLog "═══════════════════════════════════════════════"
