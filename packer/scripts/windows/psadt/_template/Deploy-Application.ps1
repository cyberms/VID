<#
.SYNOPSIS
    VID PSADT Package Template – basiert auf XOAP PSADT Framework Template (MIT)

.DESCRIPTION
    Vorlage für VID Layer 7 Applikationspakete.
    Kopiere diesen Ordner nach:
        \\<vid_smb_server>\VID-Data\apps\<AppName>\<Version>\

    Benötigte Schritte nach dem Kopieren:
    1. $appVendor, $appName, $appVersion, $appArch befüllen
    2. Installer-Datei(en) in den Files\ Ordner legen
    3. Install-/Uninstall-Logik in den jeweiligen Sektionen implementieren
    4. AppDeployToolkit\ aus _framework\ daneben legen (oder Symlink)

.PARAMETER DeploymentType
    Install | Uninstall | Repair  (Default: Install)

.PARAMETER DeployMode
    Interactive | Silent | NonInteractive  (Default: Interactive)
    → Packer-Builds immer mit -DeployMode Silent aufrufen

.EXAMPLE
    # Packer / windows-apps-install.ps1 ruft so auf:
    powershell.exe -ExecutionPolicy Bypass -NonInteractive -File ".\Deploy-Application.ps1" -DeploymentType Install -DeployMode Silent

.EXAMPLE
    # Manuelle Deinstallation:
    powershell.exe -ExecutionPolicy Bypass -NonInteractive -File ".\Deploy-Application.ps1" -DeploymentType Uninstall -DeployMode Silent

.NOTES
    PSADT Version : 3.9.2 (XOAP Framework Template)
    VID Layer     : 7 – Applikationen
    Maintainer    : <name>
    Created       : <datum>
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
    ## Execution Policy für diesen Prozess
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================

    ## App-Metadaten – HIER ANPASSEN
    [string]$appVendor       = ''          # z.B. '7-Zip'
    [string]$appName         = ''          # z.B. '7-Zip'
    [string]$appVersion      = ''          # z.B. '24.08.0'
    [string]$appArch         = 'x64'       # x64 | x86 | ''
    [string]$appLang         = 'EN'
    [string]$appRevision     = '01'
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate   = 'XX/XX/20XX'
    [string]$appScriptAuthor = '<name>'

    ## XOAP-Tag für application.XO (optional)
    [string]$appTags = ''

    ## Paketname für VID-Registry (VendorIndependenceDay\InstalledApps\<PackageName>)
    ## Konvention: <Vendor>_<AppName>_<Version>  (keine Leerzeichen)
    [string]$PackageName = "${appVendor}_${appName}_${appVersion}" -replace '\s', '_'

    ##* Do not modify section below
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
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Beispiel: App schließen falls offen (bei Packer-Builds nicht nötig)
        # Show-InstallationWelcome -CloseApps 'appname' -Silent

        ## <Hier Pre-Installation Tasks einfügen>


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## MSI-Installation (Standard):
        # Execute-MSI -Action 'Install' -Path "$dirFiles\<installer>.msi" -Parameters '/qn REBOOT=ReallySuppress'

        ## EXE-Installation:
        # Execute-Process -Path "$dirFiles\<installer>.exe" -Parameters '/S' -WindowStyle Hidden

        ## Winget (Fallback, wenn kein Installer in Files\):
        # Execute-Process -Path 'winget' -Parameters "install --id <winget.id> --version $appVersion --silent --accept-package-agreements --accept-source-agreements" -WindowStyle Hidden

        ## <Hier Installations-Tasks einfügen>


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Hier Post-Installation Tasks einfügen>
        ## z.B. Shortcuts entfernen, Registry-Tweaks, Dienste konfigurieren

        ## VID-Registrierung (immer am Ende lassen)
        Register-Installation
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## <Hier Pre-Uninstallation Tasks einfügen>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## MSI-Deinstallation:
        # Execute-MSI -Action 'Uninstall' -Path "$dirFiles\<installer>.msi"

        ## Via ProductCode:
        # Execute-MSI -Action 'Uninstall' -Path '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'

        ## <Hier Deinstallations-Tasks einfügen>


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Hier Post-Uninstallation Tasks einfügen>

        ## VID-Deregistrierung (immer am Ende lassen)
        Unregister-Installation
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## <Hier Pre-Repair Tasks einfügen>


        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## MSI-Repair:
        # Execute-MSI -Action 'Repair' -Path "$dirFiles\<installer>.msi"

        ## <Hier Repair-Tasks einfügen>


        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Hier Post-Repair Tasks einfügen>
    }

    ## Cleanup und Exit
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
