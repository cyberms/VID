<#
.SYNOPSIS
    VID PSADT Package – Adobe Acrobat Reader DC 24.5.0

.DESCRIPTION
    Installiert Adobe Acrobat Reader DC 24.5.0 (x64) per EXE.
    Installer-Datei: Files\AcroRdrDC2450420048_en_US.exe

    Download: https://get.adobe.com/reader/enterprise/
    SHA256:   Vor dem Build prüfen und hier dokumentieren.

    Installationsparameter:
      /sAll         : Silent install, alle Komponenten
      /rs           : Suppress reboot
      /rps          : Remove previous versions
      /l            : Logging aktivieren
      /msi EULA_ACCEPT=YES : EULA annehmen

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
    [string]$appVendor        = 'Adobe'
    [string]$appName          = 'Acrobat Reader DC'
    [string]$appVersion       = '24.5.0'
    [string]$appArch          = 'x64'
    [string]$appLang          = 'EN'
    [string]$appRevision      = '01'
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate    = '30/03/2026'
    [string]$appScriptAuthor  = 'VID-Team'
    [string]$appTags          = 'pdf,productivity'
    [string]$PackageName      = 'Adobe_AcrobatReaderDC_24.5.0'

    # MSI ProductCode für Deinstallation (nach Installation ermitteln)
    [string]$appMsiProductCode = '{AC76BA86-7AD7-XXXX-7960-AC98546XXXXX}'

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

        ## Alte Reader-Versionen entfernen
        $oldReader = Get-InstalledApplication -Name 'Adobe Acrobat Reader'
        If ($oldReader) {
            Write-Log -Message "Entferne alte Adobe Reader Version: $($oldReader.DisplayVersion)"
            Execute-MSI -Action 'Uninstall' -Path $oldReader.ProductCode -Parameters '/qn'
        }


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        Execute-Process -Path "$dirFiles\AcroRdrDC2450420048_en_US.exe" `
                        -Parameters '/sAll /rs /rps /l /msi EULA_ACCEPT=YES DISABLE_BROWSER_INTEGRATION=1 DISABLEDESKTOPSHORTCUT=1' `
                        -WindowStyle Hidden


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## Desktop-Shortcut entfernen (VDI-Standard)
        Remove-File -Path "$envCommonDesktop\Adobe Acrobat.lnk"    -ContinueOnError $true
        Remove-File -Path "$envCommonDesktop\Adobe Reader DC.lnk"   -ContinueOnError $true

        ## Auto-Update deaktivieren (Image-Management übernimmt Updates)
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown' `
                        -Name 'bUpdater' -Value 0 -Type DWord

        Register-Installation
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        Execute-MSI -Action 'Uninstall' -Path $appMsiProductCode -Parameters '/qn'

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        Unregister-Installation
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        Execute-MSI -Action 'Repair' -Path $appMsiProductCode -Parameters '/qn'
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
