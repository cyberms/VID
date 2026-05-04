<#
.SYNOPSIS
    VID PSADT Package – 7-Zip 24.08.0

.DESCRIPTION
    Installiert 7-Zip 24.08.0 (x64) per MSI.
    Installer-Datei: Files\7z2408-x64.msi

    Download: https://7-zip.org/a/7z2408-x64.msi
    SHA256:   Vor dem Build prüfen und hier dokumentieren.

.NOTES
    VID Layer     : 7 – Applikationen
    Maintainer    : VID-Team
    Created       : 2026-03-30
    PSADT Version : 3.9.2
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    [string]$appVendor        = '7-Zip'
    [string]$appName          = '7-Zip'
    [string]$appVersion       = '24.08.0'
    [string]$appArch          = 'x64'
    [string]$appLang          = 'EN'
    [string]$appRevision      = '01'
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate    = '30/03/2026'
    [string]$appScriptAuthor  = 'VID-Team'
    [string]$appTags          = 'compression,utility'
    [string]$PackageName      = '7-Zip_7-Zip_24.08.0'

    #region DoNotModify
    [Int32]$mainExitCode = 0
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.2'
    [String]$deployAppScriptDate = '02/02/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0) { [Int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }
    #endregion
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Alte Versionen entfernen (optional)
        # $oldVersion = Get-InstalledApplication -Name '7-Zip'
        # If ($oldVersion) {
        #     Execute-MSI -Action Uninstall -Path $oldVersion.UninstallSubkey
        # }


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        Execute-MSI -Action 'Install' `
                    -Path "$dirFiles\7z2408-x64.msi" `
                    -Parameters '/qn REBOOT=ReallySuppress ALLUSERS=1'


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## Desktop-Shortcut entfernen (VDI-Standard: keine Desktop-Icons)
        Remove-File -Path "$envCommonDesktop\7-Zip File Manager.lnk" -ContinueOnError $true

        Register-Installation
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        Execute-MSI -Action 'Uninstall' -Path "$dirFiles\7z2408-x64.msi"


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        Unregister-Installation
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR / REPAIR / POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        Execute-MSI -Action 'Repair' -Path "$dirFiles\7z2408-x64.msi" -Parameters '/qn'
    }

    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
