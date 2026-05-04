<#
.SYNOPSIS
    PSAppDeployToolkit Extensions – VID (Vendor Independence Day)

.DESCRIPTION
    Erweitert das PSADT-Framework um VID-spezifische Funktionen:
    - Register-Installation   : Schreibt App-Metadaten in die VID-Registry
    - Unregister-Installation : Entfernt App-Metadaten aus der VID-Registry

    Basiert auf dem XOAP PSADT Framework Template (MIT License).
    Angepasst für das VID-Projekt von Stefan Leveling / SAV-KB.

.NOTES
    Registry-Pfad: HKLM:\SOFTWARE\VendorIndependenceDay\InstalledApps\<PackageName>
#>

[CmdletBinding()]
Param ()

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

[string]$appDeployToolkitExtName        = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions – VID'
[version]$appDeployExtScriptVersion     = [version]'3.9.2'
[string]$appDeployExtScriptDate         = '02/02/2023'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

# VID Registry-Basispfad
[string]$vidRegBase = 'HKEY_LOCAL_MACHINE\SOFTWARE\VendorIndependenceDay\InstalledApps'

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

#region Register-Installation
Function Register-Installation {
    <#
    .SYNOPSIS
        Registriert eine erfolgreich installierte Applikation in der VID-Registry.
    .DESCRIPTION
        Schreibt App-Metadaten nach HKLM:\SOFTWARE\VendorIndependenceDay\InstalledApps\<PackageName>.
        Wird am Ende der Post-Installation aufgerufen.
    #>

    $key = "$vidRegBase\$PackageName"

    Set-RegistryKey -Key $key -Name 'IsInstalled'           -Value 1                   -Type DWord
    Set-RegistryKey -Key $key -Name 'AppName'               -Value "$appName"           -Type String
    Set-RegistryKey -Key $key -Name 'AppVendor'             -Value "$appVendor"         -Type String
    Set-RegistryKey -Key $key -Name 'AppVersion'            -Value "$appVersion"        -Type String
    Set-RegistryKey -Key $key -Name 'AppArch'               -Value "$appArch"           -Type String
    Set-RegistryKey -Key $key -Name 'AppLang'               -Value "$appLang"           -Type String
    Set-RegistryKey -Key $key -Name 'AppRevision'           -Value "$appRevision"       -Type String
    Set-RegistryKey -Key $key -Name 'ScriptVersion'         -Value "$appScriptVersion"  -Type String
    Set-RegistryKey -Key $key -Name 'ScriptDate'            -Value "$appScriptDate"     -Type String
    Set-RegistryKey -Key $key -Name 'ScriptAuthor'          -Value "$appScriptAuthor"   -Type String
    Set-RegistryKey -Key $key -Name 'PSADTVersion'          -Value "$appDeployMainScriptVersion" -Type String
    Set-RegistryKey -Key $key -Name 'InstallationDateTime'  -Value "$currentDateTime"   -Type String
    Set-RegistryKey -Key $key -Name 'InstallationSource'    -Value "$scriptParentPath"  -Type String

    $logFile = '{0}{1}' -f $logDirectory, $logName
    Set-RegistryKey -Key $key -Name 'LogFile'               -Value "$logFile"           -Type String

    Write-Log -Message "VID: Installation registriert – $PackageName v$appVersion" -Source $appDeployToolkitExtName
}
#endregion

#region Unregister-Installation
Function Unregister-Installation {
    <#
    .SYNOPSIS
        Entfernt die App-Registrierung aus der VID-Registry.
    .DESCRIPTION
        Löscht den Registry-Schlüssel unter VendorIndependenceDay\InstalledApps\<PackageName>.
        Wird am Ende der Post-Uninstallation aufgerufen.
    #>

    Remove-RegistryKey -Key "$vidRegBase\$PackageName"
    Write-Log -Message "VID: Installation deregistriert – $PackageName" -Source $appDeployToolkitExtName
}
#endregion

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================
