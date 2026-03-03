<#
    .DESCRIPTION
    Installs the Citrix Virtual Delivery Agent (VDA) for use with Citrix DaaS (Cloud) and
    Machine Creation Services (MCS). Designed for unattended Packer builds on vSphere.

    VID-Data Source (configure via Packer environment variables):
      Option A – SMB Share (primary / hypervisor-agnostic):
        VID_SMB_SERVER    = fileserver.domain.local
        VID_SMB_SHARE     = VID-Data
        VID_SMB_USERNAME  = DOMAIN\svc-packer
        VID_SMB_PASSWORD  = <password>
        VID_VDA_INSTALLER = VDAWorkstationSetup.exe

        VDA installer path on share:
          \\<VID_SMB_SERVER>\<VID_SMB_SHARE>\citrix\vda\<VID_VDA_INSTALLER>

      Option B – vSphere Datastore (fallback / vSphere-only):
        VCENTER_URL        = https://vcenter.domain.local
        VCENTER_USERNAME   = administrator@vsphere.local
        VCENTER_PASSWORD   = <password>
        VSPHERE_DATACENTER = datacenter
        VID_DATASTORE      = datastore2
        VID_PATH           = VID-Data
        VID_VDA_INSTALLER  = VDAWorkstationSetup.exe

    .NOTES
    - Use /mastermcsimage for MCS-managed (non-persistent) desktops.
    - No controller registration at build time; done via Cloud Connector / GPO.
    - Exit codes: 0 = success, 8 = reboot required (treated as success here).
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\citrix-vda-install.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

Write-Log "=== Citrix VDA Installation Start ==="
Write-Log "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Locate / download the VDA installer
#    Priority: Option A (SMB) → Option B (vCenter Datastore) → CD-ROM fallback
#
#    SMB folder structure (standardised for all customers):
#      \\<VID_SMB_SERVER>\VID-Data\
#        citrix\vda\          ← VDA installer  ← we look here
#        citrix\optimize\     ← optional custom optimize scripts
#        microsoft\avd\       ← AVD Agent (Phase 3)
#        microsoft\fslogix\   ← FSLogix (Phase 2+)
#        dex\controlup\       ← ControlUp (Layer 8, later)
#        dex\uberagent\       ← uberagent (Layer 8, later)
#        drivers\vmware\
#        drivers\xenserver\
#        apps\
# ─────────────────────────────────────────────────────────────────────────────

$VdaExe       = $null
$VdaFileName  = if ($env:VID_VDA_INSTALLER) { $env:VID_VDA_INSTALLER } else { "VDAWorkstationSetup_2511.exe" }
$LocalInstall = "C:\Windows\Temp\$VdaFileName"

# ── Option A: SMB Share (primary / hypervisor-agnostic) ──────────────────────
# Requires: VID_SMB_SERVER, VID_SMB_SHARE, VID_SMB_USERNAME, VID_SMB_PASSWORD
# The VM does NOT need to be domain-joined – credentials are passed explicitly.
if ($env:VID_SMB_SERVER -and $env:VID_SMB_SHARE) {
    Write-Log "VID-Data Source: SMB Share (Option A – primary)"
    $uncShare  = "\\$($env:VID_SMB_SERVER)\$($env:VID_SMB_SHARE)"
    $vdaSource = "$uncShare\citrix\vda\$VdaFileName"
    Write-Log "SMB share  : $uncShare"
    Write-Log "VDA source : $vdaSource"

    try {
        $secPass = ConvertTo-SecureString $env:VID_SMB_PASSWORD -AsPlainText -Force
        $cred    = New-Object System.Management.Automation.PSCredential($env:VID_SMB_USERNAME, $secPass)

        # Map share with explicit credentials (no domain join required)
        New-PSDrive -Name "VIDShare" -PSProvider FileSystem -Root $uncShare `
                    -Credential $cred -ErrorAction Stop | Out-Null
        Write-Log "SMB share mapped successfully."

        Copy-Item "VIDShare:\citrix\vda\$VdaFileName" $LocalInstall -Force -ErrorAction Stop
        Remove-PSDrive -Name "VIDShare" -ErrorAction SilentlyContinue

        $sizeMB = '{0:N1}' -f ((Get-Item $LocalInstall).Length / 1MB)
        Write-Log "VDA installer copied: $LocalInstall ($sizeMB MB)"
        $VdaExe = $LocalInstall
    }
    catch {
        Remove-PSDrive -Name "VIDShare" -ErrorAction SilentlyContinue
        Write-Log "Option A (SMB) failed: $($_.Exception.Message)" "WARN"
        Write-Log "Falling through to Option B (vCenter Datastore) or CD-ROM fallback..." "WARN"
    }
}

# ── Option B: vCenter Datastore Browser (fallback / vSphere-only) ────────────
# Requires: VCENTER_URL, VCENTER_USERNAME, VCENTER_PASSWORD,
#           VSPHERE_DATACENTER, VID_DATASTORE, VID_PATH
if (-not $VdaExe -and $env:VCENTER_URL -and $env:VID_DATASTORE -and $env:VID_PATH) {
    Write-Log "VID-Data Source: vCenter Datastore Browser (Option B – fallback)"
    $downloadUrl = "$($env:VCENTER_URL)/folder/$($env:VID_PATH)/$VdaFileName" +
                   "?dcPath=$($env:VSPHERE_DATACENTER)&dsName=$($env:VID_DATASTORE)"
    Write-Log "Download URL: $downloadUrl"

    try {
        add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) { return true; }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12

        $secPass = ConvertTo-SecureString $env:VCENTER_PASSWORD -AsPlainText -Force
        $cred    = New-Object System.Management.Automation.PSCredential($env:VCENTER_USERNAME, $secPass)

        Write-Log "Downloading from vCenter datastore '$($env:VID_DATASTORE)/$($env:VID_PATH)'..."
        Invoke-WebRequest -Uri $downloadUrl -Credential $cred -OutFile $LocalInstall -UseBasicParsing
        Write-Log "Download complete: $LocalInstall ($('{0:N1}' -f ((Get-Item $LocalInstall).Length / 1MB)) MB)"
        $VdaExe = $LocalInstall
    }
    catch {
        Write-Log "Option B (vCenter Datastore) failed: $($_.Exception.Message)" "WARN"
        Write-Log "Falling through to CD-ROM fallback..." "WARN"
    }
}

# ── Fallback: CD-ROM detection (legacy / manual builds without env vars) ──────
if (-not $VdaExe) {
    Write-Log "VID-Data Source: CD-ROM fallback (no SMB / Datastore env vars set)"
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'CDRom' -and $_.IsReady }
    foreach ($drive in $drives) {
        Write-Log "Checking drive $($drive.Name)..."
        $candidate = Get-ChildItem -Path $drive.RootDirectory -Filter "VDAWorkstationSetup*.exe" `
                                   -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) {
            $VdaExe = $candidate.FullName
            Write-Log "Found VDA installer on CD-ROM: $VdaExe"
            break
        }
    }
}

if (-not $VdaExe) {
    Write-Log "ERROR: Citrix VDA installer not found via SMB, vCenter Datastore, or CD-ROM." "ERROR"
    throw "Citrix VDA installer '$VdaFileName' not found. " +
          "Set VID_SMB_SERVER + VID_SMB_SHARE env vars, or VCENTER_URL + VID_DATASTORE, or mount the Citrix ISO."
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Define installation parameters
# ─────────────────────────────────────────────────────────────────────────────

# Components to include (comma-separated, no spaces around commas in the string)
# Ref: https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/install-configure/install-command.html
$IncludeComponents = @(
    "Citrix User Profile Manager",
    "Citrix User Profile Manager WMI Plugin",
    "Machine Identity Service",
    "Citrix Telemetry Service",
    "Browser Content Redirection"
) -join ","

# Components to exclude (not needed for MCS managed desktops)
$ExcludeComponents = @(
    "Citrix Supportability Tools",
    "Personal vDisk"
) -join ","

$VdaArguments = @(
    "/quiet",                          # Silent install
    "/noreboot",                       # Packer manages reboots
    "/enable_hdx_ports",               # Open Citrix HDX firewall ports (1494, 2598)
    "/enable_real_time_transport",     # Enable Enlightened Data Transport (UDP/EDT)
    "/enable_ss_ports",               # Enable Session Sharing ports
    "/virtualmachine",                 # Optimize for virtual machine deployment
    "/mastermcsimage",                 # Mark as MCS master image (no VDA registration at build time)
    "/includeadditional `"$IncludeComponents`"",
    "/exclude `"$ExcludeComponents`"",
    "/logpath C:\Windows\Temp\CitrixVDAInstall"
)

$ArgumentString = $VdaArguments -join " "
Write-Log "VDA installer: $VdaExe"
Write-Log "Arguments: $ArgumentString"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Run the VDA installation
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "Starting Citrix VDA installation... (this may take 10-20 minutes)"

try {
    $process = Start-Process -FilePath $VdaExe `
        -ArgumentList $ArgumentString `
        -Wait -PassThru -NoNewWindow

    $exitCode = $process.ExitCode
    Write-Log "VDA installer exited with code: $exitCode"

    # Citrix VDA exit codes
    # 0   = Success
    # 3    = Partial success
    # 8   = Success, reboot required (expected with /noreboot)
    # 1641 = Success, reboot required (MSI)
    # 3010 = Success, reboot required (MSI)

    switch ($exitCode) {
        0    { Write-Log "VDA installation completed successfully." }
        3    { Write-Log "VDA installation partially successful. Review logs." "WARN" }
        8    { Write-Log "VDA installation successful. Reboot required (will be handled by Packer)." }
        1641 { Write-Log "VDA installation successful. Reboot required (MSI code 1641)." }
        3010 { Write-Log "VDA installation successful. Reboot required (MSI code 3010)." }
        default {
            Write-Log "VDA installation returned unexpected exit code: $exitCode" "ERROR"
            throw "Citrix VDA installation failed with exit code $exitCode. Check logs in C:\Windows\Temp\CitrixVDAInstall\"
        }
    }
}
catch {
    Write-Log "Exception during VDA installation: $($_.Exception.Message)" "ERROR"
    throw
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Verify key VDA files are present
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "Verifying VDA installation..."

$vdaPath = "$env:ProgramFiles\Citrix\Virtual Desktop Agent"
if (Test-Path $vdaPath) {
    Write-Log "VDA directory found: $vdaPath"

    $brokerAgent = Join-Path $vdaPath "BrokerAgent.exe"
    if (Test-Path $brokerAgent) {
        $version = (Get-Item $brokerAgent).VersionInfo.FileVersion
        Write-Log "BrokerAgent.exe version: $version"
    } else {
        Write-Log "WARNING: BrokerAgent.exe not found at expected location." "WARN"
    }
} else {
    Write-Log "WARNING: VDA directory not found at $vdaPath – install may be incomplete." "WARN"
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Configure VDA for Citrix DaaS (Cloud)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "Configuring VDA registry settings for Citrix DaaS..."

# ListOfDDCs / Controllers can be overridden later via GPO or Citrix Policy
# For DaaS/Cloud, the Cloud Connector is the DDC – set via GPO or ADMX
# The following keys ensure the VDA is cloud-ready
$regPath = "HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent"

if (Test-Path $regPath) {
    # Ensure the VDA does not try to register immediately (MCS master image)
    # The controllers will be set by the Cloud Connector auto-discovery
    Set-ItemProperty -Path $regPath -Name "EnableAutoUpdateFeature" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "VDA registry configured."
} else {
    Write-Log "VDA registry path not found – will be created on first boot." "WARN"
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Configure Citrix HDX firewall rules (in case /enable_hdx_ports missed any)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "Verifying Citrix HDX firewall rules..."

$citrixRules = @(
    @{Name="Citrix ICA (TCP)";     Protocol="TCP"; Port=1494},
    @{Name="Citrix CGP (TCP)";     Protocol="TCP"; Port=2598},
    @{Name="Citrix EDT (UDP)";     Protocol="UDP"; Port=1494},
    @{Name="Citrix EDT CGP (UDP)"; Protocol="UDP"; Port=2598},
    @{Name="Citrix MSI (TCP)";     Protocol="TCP"; Port=8008}
)

foreach ($rule in $citrixRules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule `
            -DisplayName $rule.Name `
            -Direction Inbound `
            -Protocol $rule.Protocol `
            -LocalPort $rule.Port `
            -Action Allow `
            -Profile Any | Out-Null
        Write-Log "Created firewall rule: $($rule.Name) ($($rule.Protocol):$($rule.Port))"
    } else {
        Write-Log "Firewall rule already exists: $($rule.Name)"
    }
}

Write-Log "=== Citrix VDA Installation Complete ==="
Write-Log "Log file: $LogFile"
Write-Log "Citrix VDA install logs: C:\Windows\Temp\CitrixVDAInstall\"
Write-Log "A reboot is required to complete the VDA installation."
