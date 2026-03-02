<#
    .DESCRIPTION
    Vendor Independence Day (VID) - Layer 6: Driver Abstraction
    
    Detects the underlying hypervisor and installs the appropriate guest tools/drivers.
    Supports: VMware vSphere, Citrix Hypervisor (XenServer)
    
    Design principle: The Windows 11 base image (Layer 5) is hypervisor-agnostic.
    This script forms the "Driver Layer" (Layer 6) bridge between OS and hypervisor.
    
    Detection method: CPUID / WMI BIOS manufacturer string
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\vid-hypervisor-detect.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

Write-Log "=== VID Layer 6: Hypervisor Detection and Driver Installation ==="

# ─────────────────────────────────────────────────────────────────────────────
# 1. Detect Hypervisor
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- [1] Detecting Hypervisor ---"

$hypervisor = "Unknown"
$detectionMethod = ""

# Method A: WMI BIOS / System Manufacturer
try {
    $bios = Get-WmiObject -Class Win32_BIOS -ErrorAction Stop
    $system = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
    
    Write-Log "  BIOS Manufacturer : $($bios.Manufacturer)"
    Write-Log "  BIOS Version      : $($bios.SMBIOSBIOSVersion)"
    Write-Log "  System Mfg        : $($system.Manufacturer)"
    Write-Log "  System Model      : $($system.Model)"
    
    if ($bios.Manufacturer -like "*VMware*" -or $system.Manufacturer -like "*VMware*" -or $system.Model -like "*VMware*") {
        $hypervisor = "VMware"
        $detectionMethod = "WMI BIOS/System"
    }
    elseif ($bios.Manufacturer -like "*Xen*" -or $system.Manufacturer -like "*Xen*" -or 
            $bios.SMBIOSBIOSVersion -like "*Xen*" -or $system.Model -like "*HVM*") {
        $hypervisor = "XenServer"
        $detectionMethod = "WMI BIOS/System"
    }
}
catch { Write-Log "  WMI detection warning: $($_.Exception.Message)" "WARN" }

# Method B: Registry (hypervisor signature)
if ($hypervisor -eq "Unknown") {
    try {
        $hvPath = "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters"
        if (Test-Path $hvPath) {
            $hvName = (Get-ItemProperty $hvPath -ErrorAction SilentlyContinue).HostName
            Write-Log "  VM Guest Registry HostName: $hvName"
            if ($hvName -like "*vmware*" -or $hvName -like "*vcenter*") {
                $hypervisor = "VMware"
                $detectionMethod = "Registry Guest Parameters"
            }
        }
    }
    catch { Write-Log "  Registry detection warning: $($_.Exception.Message)" "WARN" }
}

# Method C: PCI device detection (fallback)
if ($hypervisor -eq "Unknown") {
    try {
        $pciDevices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.Name -match "VMware|VMXNET|PVSCSI|XenBus|Xen PCI" }
        if ($pciDevices | Where-Object { $_.Name -match "VMware|VMXNET|PVSCSI" }) {
            $hypervisor = "VMware"
            $detectionMethod = "PCI Device"
        }
        elseif ($pciDevices | Where-Object { $_.Name -match "XenBus|Xen PCI" }) {
            $hypervisor = "XenServer"
            $detectionMethod = "PCI Device"
        }
    }
    catch { Write-Log "  PCI detection warning: $($_.Exception.Message)" "WARN" }
}

Write-Log "  Detected Hypervisor: $hypervisor (via: $detectionMethod)"

# Write hypervisor info to registry for future reference
$vidRegPath = "HKLM:\SOFTWARE\VendorIndependenceDay"
if (-not (Test-Path $vidRegPath)) { New-Item -Path $vidRegPath -Force | Out-Null }
Set-ItemProperty -Path $vidRegPath -Name "Hypervisor"       -Value $hypervisor       -Type String
Set-ItemProperty -Path $vidRegPath -Name "DetectionMethod"  -Value $detectionMethod  -Type String
Set-ItemProperty -Path $vidRegPath -Name "ImageBuildDate"   -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Type String
Set-ItemProperty -Path $vidRegPath -Name "VIDLayer"         -Value "6-Drivers"       -Type String
Write-Log "  VID metadata written to HKLM:\SOFTWARE\VendorIndependenceDay"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Install Hypervisor-Specific Tools
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- [2] Installing Hypervisor Guest Tools (Layer 6) ---"

switch ($hypervisor) {
    "VMware" {
        Write-Log "  -> Delegating to windows-vmtools.ps1 for VMware Tools installation"
        $scriptPath = Join-Path $PSScriptRoot "windows-vmtools.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath
        } else {
            Write-Log "  WARNING: windows-vmtools.ps1 not found at $scriptPath" "WARN"
            Write-Log "  VMware Tools should already be installed via autounattend FirstLogonCommands" "WARN"
        }
    }
    "XenServer" {
        Write-Log "  -> Delegating to windows-xenserver-tools.ps1 for Citrix VM Tools installation"
        $scriptPath = Join-Path $PSScriptRoot "windows-xenserver-tools.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath
        } else {
            Write-Log "  ERROR: windows-xenserver-tools.ps1 not found at $scriptPath" "ERROR"
            throw "XenServer tools script not found. Cannot install guest tools."
        }
    }
    default {
        Write-Log "  WARNING: Hypervisor '$hypervisor' not recognized. No tools installed." "WARN"
        Write-Log "  Supported hypervisors: VMware, XenServer" "WARN"
        Write-Log "  Manual tool installation may be required." "WARN"
    }
}

Write-Log "=== VID Layer 6: Driver Installation Complete. Hypervisor: $hypervisor ==="
Write-Log "Log: $LogFile"
