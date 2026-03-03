<#
    .SYNOPSIS
    Deploys or updates a Citrix DaaS (Cloud) MCS Machine Catalog and Delivery Group
    using the Citrix DaaS Remote PowerShell SDK.

    .DESCRIPTION
    This script:
      1. Authenticates against Citrix Cloud using a Secure Client (API key)
      2. Selects the correct Citrix DaaS zone / resource location
      3. Creates or updates a Machine Catalog (MCS, Non-Persistent/Persistent)
      4. Provisions a configurable number of VMs from the master image
      5. Creates or updates a Delivery Group and assigns AD security groups

    .PREREQUISITES
    - Citrix DaaS Remote PowerShell SDK installed:
        https://www.citrix.com/downloads/citrix-cloud/product-software/xenapp-and-xendesktop-service.html
      Install via: Install-Module -Name Citrix.DaaS.SDK (or install the MSI)
    - A Citrix Cloud Secure Client (client_id + client_secret) with admin rights
    - A vSphere Hosting Connection already configured in Citrix DaaS
    - The Packer master image VM must exist in vSphere (snapshot taken by Packer
      or manually after the Packer build completes)

    .PARAMETER CitrixClientId
    Citrix Cloud Secure Client ID (from https://api.cloud.com)

    .PARAMETER CitrixClientSecret
    Citrix Cloud Secure Client Secret

    .PARAMETER CustomerId
    Citrix Cloud Customer ID (shown in Citrix Cloud console)

    .PARAMETER MasterImageVM
    Full vSphere path to the master image VM, e.g.:
    "XDHyp:\Connections\vSphere-Connection\Datacenter.datacenter\cluster.cluster\masterimage-vm.vm\snapshot.snapshot"

    .PARAMETER CatalogName
    Name for the Machine Catalog (will be created if not exists, updated if exists)

    .PARAMETER DeliveryGroupName
    Name for the Delivery Group

    .PARAMETER VmCount
    Number of VMs to provision in the catalog

    .PARAMETER UserGroups
    AD group(s) to assign to the Delivery Group (comma-separated DOMAIN\Group format)

    .EXAMPLE
    .\deploy-citrix-mcs.ps1 `
        -CitrixClientId     "YOUR_CLIENT_ID" `
        -CitrixClientSecret "YOUR_CLIENT_SECRET" `
        -CustomerId         "YOUR_CUSTOMER_ID" `
        -MasterImageVM      "XDHyp:\Connections\vSphere-euc-demo\Datacenter.datacenter\cluster01.cluster\windows-desktop-11-vda.vm\packer-snapshot.snapshot" `
        -CatalogName        "W11-Citrix-VDA-MCS" `
        -DeliveryGroupName  "W11-Desktop-Pool" `
        -VmCount            10 `
        -UserGroups         "DOMAIN\Citrix-Desktop-Users","DOMAIN\Developers"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CitrixClientId,
    [Parameter(Mandatory)][string]$CitrixClientSecret,
    [Parameter(Mandatory)][string]$CustomerId,
    [Parameter(Mandatory)][string]$MasterImageVM,
    [Parameter(Mandatory)][string]$CatalogName,
    [Parameter(Mandatory)][string]$DeliveryGroupName,
    [Parameter()]         [int]   $VmCount             = 5,
    [Parameter()]         [string[]]$UserGroups         = @(),
    [Parameter()]         [string]$NamingScheme         = "W11-VDA-###",
    [Parameter()]         [string]$NamingSchemeType     = "Numeric",
    [Parameter()]         [string]$NetworkPath          = "",       # XDHyp path to vSphere network
    [Parameter()]         [string]$StoragePath          = "",       # XDHyp path to vSphere datastore
    [Parameter()]         [int]   $CpuCount             = 2,
    [Parameter()]         [int]   $MemoryMB             = 4096,
    [Parameter()]         [string]$SessionSupport       = "SingleSession",     # oder "MultiSession"
    [Parameter()]         [string]$AllocationType       = "Random",            # Random = Nicht-persistent (kein anderer Wert vorgesehen)
    [Parameter()]         [string]$PersistenceType      = "Discard",           # Discard = Nicht-persistent (VM-Änderungen verworfen beim Neustart)
    [Parameter()]         [string]$ProvisioningType     = "MCS",
    [Parameter()]         [string]$DomainController     = "",
    [Parameter()]         [string]$OUPath               = "",                  # e.g. "OU=VDA,OU=Citrix,DC=domain,DC=local"
    [Parameter()]         [string]$DomainServiceAccount = "",                  # DOMAIN\svc-citrix-mcs
    [Parameter()]         [string]$DomainServicePassword= "",
    [Parameter()]         [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $PSScriptRoot "deploy-citrix-mcs-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry
}

function Assert-DaasModule {
    $sdkModules = @(
        "Citrix.DaaS.SDK",
        "Citrix.Broker.Commands",
        "Citrix.MachineCreation.Commands",
        "Citrix.Host.Commands",
        "Citrix.ADIdentity.Commands"
    )
    $missing = $sdkModules | Where-Object { -not (Get-Module -ListAvailable -Name $_) }
    if ($missing) {
        Write-Log "Missing Citrix DaaS SDK modules: $($missing -join ', ')" "ERROR"
        Write-Log "Install from: https://www.citrix.com/downloads/citrix-cloud/" "ERROR"
        Write-Log "Or run: Install-Module -Name Citrix.DaaS.SDK" "ERROR"
        throw "Citrix DaaS Remote PowerShell SDK not installed."
    }
    Write-Log "Citrix DaaS SDK modules found."
}

Write-Log "==================================================="
Write-Log " Citrix DaaS MCS Deployment Script"
Write-Log "==================================================="
Write-Log "Customer ID:      $CustomerId"
Write-Log "Catalog Name:     $CatalogName"
Write-Log "Delivery Group:   $DeliveryGroupName"
Write-Log "Master Image:     $MasterImageVM"
Write-Log "VM Count:         $VmCount"
Write-Log "Naming Scheme:    $NamingScheme"
Write-Log "Session Support:  $SessionSupport"
Write-Log "Allocation Type:  $AllocationType"
Write-Log "WhatIf:           $WhatIf"
Write-Log "==================================================="

# ─────────────────────────────────────────────────────────────────────────────
# 1. Check and Import Citrix DaaS SDK
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [1] Loading Citrix DaaS PowerShell SDK ---"
Assert-DaasModule

Import-Module Citrix.DaaS.SDK -Force -ErrorAction Stop
Write-Log "  Citrix DaaS SDK loaded."

# ─────────────────────────────────────────────────────────────────────────────
# 2. Authenticate to Citrix Cloud
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [2] Authenticating to Citrix Cloud ---"

$SecureSecret = ConvertTo-SecureString $CitrixClientSecret -AsPlainText -Force
$Credential   = New-Object System.Management.Automation.PSCredential($CitrixClientId, $SecureSecret)

try {
    Set-XDCredentials -CustomerId $CustomerId -APIKey $CitrixClientId -SecretKey $CitrixClientSecret -ProfileType CloudAPI
    Write-Log "  Citrix Cloud authentication successful."
}
catch {
    Write-Log "  Authentication failed: $($_.Exception.Message)" "ERROR"
    throw
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Get Hosting Connection and validate master image path
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [3] Validating Hosting Connection and Master Image ---"

# List available hosting connections (for informational output)
$hostingConnections = Get-ChildItem -Path "XDHyp:\Connections\" -ErrorAction SilentlyContinue
Write-Log "  Available hosting connections:"
$hostingConnections | ForEach-Object { Write-Log "    - $($_.Name)" }

# Validate the master image path exists
if (-not (Test-Path $MasterImageVM)) {
    Write-Log "  Master image path not found: $MasterImageVM" "ERROR"
    Write-Log "  Available paths:" "ERROR"
    Write-Log "  Use: Get-ChildItem -Path 'XDHyp:\Connections\<your-connection>\' -Recurse" "ERROR"
    throw "Master image VM path '$MasterImageVM' not found in vSphere hosting connection."
}
Write-Log "  Master image path validated: $MasterImageVM"

# Extract connection name from path for later use
$connectionName = ($MasterImageVM -split '\\')[2]
$hostConn = Get-Item -Path "XDHyp:\Connections\$connectionName"
Write-Log "  Using hosting connection: $connectionName (UID: $($hostConn.HypervisorConnectionUid))"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Build Domain Identity Pool Credentials
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [4] Configuring Domain Identity ---"

$adIdentityParams = @{
    NamingScheme     = $NamingScheme
    NamingSchemeType = $NamingSchemeType
}

if ($OUPath) {
    $adIdentityParams["OU"] = $OUPath
    Write-Log "  OU for computer accounts: $OUPath"
}

if ($DomainServiceAccount -and $DomainServicePassword) {
    $adIdentityParams["Domain"] = ($DomainServiceAccount -split "\\")[0]
    Write-Log "  Domain: $($adIdentityParams['Domain'])"
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Create or Update Machine Catalog
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [5] Machine Catalog: $CatalogName ---"

$existingCatalog = Get-BrokerCatalog -Name $CatalogName -ErrorAction SilentlyContinue

if ($existingCatalog) {
    Write-Log "  Existing catalog found: $CatalogName (UID: $($existingCatalog.Uid))"
    Write-Log "  Will update master image and provision new machines."

    # Update the master image in the provisioning scheme
    if (-not $WhatIf) {
        Write-Log "  Publishing new master image to catalog..."
        $provScheme = Get-ProvScheme -ProvisioningSchemeName $CatalogName -ErrorAction SilentlyContinue

        if ($provScheme) {
            Publish-ProvMasterVmImage `
                -ProvisioningSchemeName $CatalogName `
                -MasterImageVM $MasterImageVM `
                -RunAsynchronously
            Write-Log "  Master image update initiated asynchronously."
        }
    } else {
        Write-Log "  [WhatIf] Would update master image in catalog '$CatalogName'."
    }

} else {
    Write-Log "  Creating new Machine Catalog: $CatalogName"

    # Create the Provisioning Scheme (MCS configuration)
    $provSchemeParams = @{
        ProvisioningSchemeName           = $CatalogName
        HostingUnitName                  = $connectionName
        MasterImageVM                    = $MasterImageVM
        VMCpuCount                       = $CpuCount
        VMMemoryMB                       = $MemoryMB
        CleanOnBoot                      = ($PersistenceType -eq "Discard")  # True = Non-Persistent
        UsePersonalVDiskStorage          = $false
        RunAsynchronously                = $false
        NamingScheme                     = $NamingScheme
        NamingSchemeType                 = $NamingSchemeType
    }

    if ($NetworkPath)  { $provSchemeParams["NetworkMapping"] = @{ "0" = $NetworkPath } }
    if ($StoragePath)  { $provSchemeParams["StorageAccountType"] = "Standard_LRS"; $provSchemeParams["StoragePath"] = @($StoragePath) }
    if ($OUPath)       { $provSchemeParams["OU"] = $OUPath }

    if ($DomainServiceAccount -and $DomainServicePassword) {
        $provSchemeParams["ServiceAccountName"]     = $DomainServiceAccount
        $provSchemeParams["ServiceAccountPassword"] = (ConvertTo-SecureString $DomainServicePassword -AsPlainText -Force)
    }

    if (-not $WhatIf) {
        Write-Log "  Creating provisioning scheme (MCS)..."
        $provScheme = New-ProvScheme @provSchemeParams
        Write-Log "  Provisioning scheme created: $($provScheme.ProvisioningSchemeUid)"

        # Create the Broker Machine Catalog
        $catalogParams = @{
            Name                 = $CatalogName
            Description          = "Windows 11 + Citrix VDA - MCS Managed - Built by Packer on $(Get-Date -Format 'yyyy-MM-dd')"
            AllocationType       = $AllocationType
            SessionSupport       = $SessionSupport
            PersistUserChanges   = $PersistenceType
            ProvisioningType     = $ProvisioningType
            ProvisioningSchemeId = $provScheme.ProvisioningSchemeUid
            MachinesArePhysical  = $false
        }

        $catalog = New-BrokerCatalog @catalogParams
        Write-Log "  Broker Machine Catalog created: $($catalog.Uid)"
    } else {
        Write-Log "  [WhatIf] Would create catalog '$CatalogName' with MCS provisioning scheme."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Provision VMs (create AD computer accounts + VM clones)
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [6] Provisioning $VmCount VMs ---"

if (-not $WhatIf) {
    $catalog = Get-BrokerCatalog -Name $CatalogName

    # Create AD computer account identities
    Write-Log "  Creating $VmCount AD computer accounts..."
    $adAccountParams = @{
        IdentityPoolName = $CatalogName
        Count            = $VmCount
    }
    if ($DomainController) { $adAccountParams["ADUserName"] = $DomainServiceAccount }

    $adAccounts = New-AcctADAccount @adAccountParams
    Write-Log "  AD accounts created: $($adAccounts.SuccessfulAccountsCount)"

    if ($adAccounts.FailedAccountsCount -gt 0) {
        Write-Log "  WARNING: $($adAccounts.FailedAccountsCount) AD account creation failures!" "WARN"
        $adAccounts.FailedAccounts | ForEach-Object { Write-Log "    Failed: $_" "WARN" }
    }

    # Provision VMs from the master image via MCS
    Write-Log "  Provisioning $VmCount VMs via MCS..."
    $provTask = New-ProvVM `
        -ProvisioningSchemeName $CatalogName `
        -ADAccountName $adAccounts.SuccessfulAccounts.ADAccountName `
        -RunAsynchronously

    Write-Log "  MCS provisioning task started: $($provTask.TaskId)"
    Write-Log "  Waiting for provisioning to complete..."

    $maxWaitMinutes = 60
    $waited = 0
    do {
        Start-Sleep -Seconds 30
        $waited += 0.5
        $taskStatus = Get-ProvTask -TaskId $provTask.TaskId
        $pct = if ($taskStatus.TaskExpectedDurationMins -gt 0) {
            [int](($waited / $taskStatus.TaskExpectedDurationMins) * 100)
        } else { 0 }
        Write-Log "  Provisioning status: $($taskStatus.TaskState) (${pct}%)"
    } while ($taskStatus.TaskState -notin @("Finished","Cancelled","Error") -and $waited -lt $maxWaitMinutes)

    if ($taskStatus.TaskState -eq "Finished") {
        Write-Log "  VM provisioning completed successfully."
        Write-Log "  VMs provisioned: $($taskStatus.CreatedVirtualMachineCount)"
        Write-Log "  VMs failed:      $($taskStatus.FailedVirtualMachineCount)"
    } else {
        Write-Log "  Provisioning ended with state: $($taskStatus.TaskState)" "WARN"
        if ($taskStatus.ErrorCode) {
            Write-Log "  Error: $($taskStatus.ErrorCode) - $($taskStatus.ErrorMessage)" "ERROR"
        }
    }

    # Lock provisioned VMs and add to Broker catalog
    Write-Log "  Adding provisioned VMs to catalog '$CatalogName'..."
    $provVMs = Get-ProvVM -ProvisioningSchemeName $CatalogName
    foreach ($vm in $provVMs) {
        Lock-ProvVM -ProvisioningSchemeName $CatalogName -Tag "Brokered" -VMID @($vm.VMId) -ErrorAction SilentlyContinue
        New-BrokerMachine -MachineName $vm.ADAccountName -CatalogUid $catalog.Uid | Out-Null
    }
    Write-Log "  $($provVMs.Count) VMs added to catalog."
} else {
    Write-Log "  [WhatIf] Would provision $VmCount VMs in catalog '$CatalogName'."
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. Create or Update Delivery Group
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [7] Delivery Group: $DeliveryGroupName ---"

$existingDG = Get-BrokerDesktopGroup -Name $DeliveryGroupName -ErrorAction SilentlyContinue

if (-not $existingDG) {
    Write-Log "  Creating Delivery Group: $DeliveryGroupName"

    if (-not $WhatIf) {
        $dg = New-BrokerDesktopGroup `
            -Name                $DeliveryGroupName `
            -Description         "Windows 11 VDI Pool - Citrix DaaS MCS" `
            -DesktopKind         "Shared" `
            -SessionSupport      $SessionSupport `
            -DeliveryType        "DesktopsOnly" `
            -Enabled             $true

        Write-Log "  Delivery Group created: $($dg.Uid)"

        # Add all machines from the catalog to the delivery group
        $catalog = Get-BrokerCatalog -Name $CatalogName
        $machines = Get-BrokerMachine -CatalogName $CatalogName
        foreach ($machine in $machines) {
            Add-BrokerMachine -MachineName $machine.MachineName -DesktopGroup $dg | Out-Null
        }
        Write-Log "  Added $($machines.Count) machines to Delivery Group."

        # Create a Desktop entitlement rule (the "desktop" resource users can launch)
        New-BrokerEntitlementPolicyRule `
            -DesktopGroupUid $dg.Uid `
            -Name            "$DeliveryGroupName-Desktop" `
            -IncludedUsers   @("Authenticated Users") `
            -Enabled         $true | Out-Null
        Write-Log "  Desktop entitlement rule created."
    } else {
        Write-Log "  [WhatIf] Would create Delivery Group '$DeliveryGroupName'."
    }
} else {
    Write-Log "  Delivery Group already exists: $DeliveryGroupName (UID: $($existingDG.Uid))"

    if (-not $WhatIf) {
        # Add any newly provisioned machines to the existing delivery group
        $unassignedMachines = Get-BrokerMachine -CatalogName $CatalogName | Where-Object { -not $_.DesktopGroupName }
        foreach ($machine in $unassignedMachines) {
            Add-BrokerMachine -MachineName $machine.MachineName -DesktopGroup $existingDG | Out-Null
        }
        Write-Log "  Added $($unassignedMachines.Count) new machines to existing Delivery Group."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 8. Assign User Groups to Delivery Group
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [8] User/Group Assignment ---"

if ($UserGroups.Count -gt 0) {
    $dg = Get-BrokerDesktopGroup -Name $DeliveryGroupName

    foreach ($group in $UserGroups) {
        Write-Log "  Assigning group: $group"
        if (-not $WhatIf) {
            try {
                Add-BrokerAccessPolicyRule `
                    -Name             "$DeliveryGroupName-Access-$(($group -replace '[\\@]','-'))" `
                    -DesktopGroupUid  $dg.Uid `
                    -IncludedSmartAccessFilterEnabled $false `
                    -IncludedUsers    @($group) `
                    -AllowedConnections "AnyViaAG" `
                    -Enabled          $true `
                    -ErrorAction      SilentlyContinue | Out-Null

                Add-BrokerUser $group -DesktopGroup $dg | Out-Null
                Write-Log "    Group '$group' assigned to Delivery Group."
            }
            catch {
                Write-Log "    Warning: Could not assign '$group': $($_.Exception.Message)" "WARN"
            }
        } else {
            Write-Log "  [WhatIf] Would assign group '$group' to '$DeliveryGroupName'."
        }
    }
} else {
    Write-Log "  No user groups specified. Add users/groups manually in Citrix DaaS console."
}

# ─────────────────────────────────────────────────────────────────────────────
# 9. Deployment Summary
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "==================================================="
Write-Log " Deployment Summary"
Write-Log "==================================================="

if (-not $WhatIf) {
    $catalog = Get-BrokerCatalog -Name $CatalogName -ErrorAction SilentlyContinue
    $dg      = Get-BrokerDesktopGroup -Name $DeliveryGroupName -ErrorAction SilentlyContinue
    $machines = Get-BrokerMachine -CatalogName $CatalogName -ErrorAction SilentlyContinue

    Write-Log "  Machine Catalog:   $CatalogName"
    Write-Log "  Catalog UID:       $($catalog.Uid)"
    Write-Log "  Total Machines:    $($machines.Count)"
    Write-Log "  Delivery Group:    $DeliveryGroupName"
    Write-Log "  DG UID:            $($dg.Uid)"
    Write-Log "  DG Enabled:        $($dg.Enabled)"

    Write-Log ""
    Write-Log "  MACHINES:"
    $machines | ForEach-Object {
        Write-Log "    $($_.MachineName) | $($_.PowerState) | $($_.RegistrationState)"
    }
} else {
    Write-Log "  [WhatIf] No changes were made. Run without -WhatIf to deploy."
}

Write-Log ""
Write-Log "  Log file: $LogFile"
Write-Log "==================================================="
Write-Log " Citrix DaaS MCS Deployment Complete"
Write-Log "==================================================="
