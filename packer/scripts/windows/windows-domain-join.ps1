# =============================================================================
# windows-domain-join.ps1
# Vendor Independence Day (VID) - Active Directory Domain Join
#
# Nimmt die Packer-Build-VM in die AD auf und legt den Computer-Account
# in der definierten OU ab.
#
# Wird als Packer-Provisioner ausgefuehrt, NACH Windows Updates
# und VOR der Citrix VDA Installation.
#
# Parameter werden von Packer als Umgebungsvariablen uebergeben.
# =============================================================================

param(
    [string]$DomainName     = $env:PKR_VAR_domain_name,
    [string]$DomainUser     = $env:PKR_VAR_domain_join_username,
    [string]$DomainPassword = $env:PKR_VAR_domain_join_password,
    [string]$OUPath         = $env:PKR_VAR_domain_join_ou,
    [string]$ComputerName   = $env:PKR_VAR_domain_join_computer_name
)

# -- Eingaben pruefen -----------------------------------------------------------
if (-not $DomainName -or -not $DomainUser -or -not $DomainPassword) {
    Write-Error "Domain-Join: Fehlende Pflichtparameter (DomainName, DomainUser, DomainPassword)."
    Write-Error "Bitte domain_name, domain_join_username und domain_join_password in build.pkrvars.hcl setzen."
    exit 1
}

Write-Output "=========================================================="
Write-Output "  VID - Active Directory Domain Join"
Write-Output "  Domain  : $DomainName"
Write-Output "  OU      : $(if ($OUPath) { $OUPath } else { 'Standard (CN=Computers)' })"
Write-Output "  Account : $DomainUser"
Write-Output "  ComputerName: $(if ($ComputerName) { $ComputerName } else { '(Windows-generiert)' })"
Write-Output "=========================================================="

# -- Secure Credential erstellen -----------------------------------------------
$SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
$Credential     = New-Object System.Management.Automation.PSCredential($DomainUser, $SecurePassword)

# -- Aktuellen Status pruefen ---------------------------------------------------
$CurrentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
if ($CurrentDomain -eq $DomainName) {
    Write-Output "VM ist bereits Mitglied der Domain '$DomainName'. Kein Join notwendig."
    exit 0
}

Write-Output "Aktuelle Domain/Workgroup: $CurrentDomain"
Write-Output "Starte Domain-Join..."

# -- Stale computer account entfernen ------------------------------------------
# Packer-Builds hinterlassen den Computer-Account (z.B. VID-W11-Master) nach
# einem fehlgeschlagenen Build in der AD. Beim naechsten Build schlaegt dann
# Add-Computer -NewName fehl mit "The account already exists."
# Loesung: ADSI-Suche mit Domain-Credentials vor dem Join, Account loeschen
# falls vorhanden.
if ($ComputerName) {
    try {
        Write-Output "Pruefen auf vorhandenen Computer-Account '$ComputerName' in AD..."
        $ldapRoot = New-Object System.DirectoryServices.DirectoryEntry(
            "LDAP://$DomainName",
            $DomainUser,
            $DomainPassword
        )
        $searcher = New-Object System.DirectoryServices.DirectorySearcher($ldapRoot)
        $searcher.Filter = "(&(objectClass=computer)(cn=$ComputerName))"
        $searcher.SearchScope = "Subtree"
        $result = $searcher.FindOne()

        if ($result) {
            Write-Output "Vorhandenen (veralteten) Computer-Account gefunden, wird entfernt..."
            $staleEntry = $result.GetDirectoryEntry()
            $staleEntry.DeleteTree()
            Write-Output "Computer-Account '$ComputerName' aus der AD entfernt."
        } else {
            Write-Output "Kein vorhandener Computer-Account gefunden."
        }
    } catch {
        # Nicht fatal - wenn der Account nicht geloescht werden kann,
        # versucht Add-Computer trotzdem den Join (kann klappen wenn
        # der Account in einer anderen OU liegt oder bereits korrekt ist).
        Write-Output "Hinweis: Konnte vorhandenen Account nicht pruefen/loeschen: $_ (kein Fehler)"
    }
}

# -- Domain-Join ---------------------------------------------------------------
try {
    $JoinParams = @{
        DomainName  = $DomainName
        Credential  = $Credential
        Force       = $true
    }

    if ($OUPath) {
        $JoinParams["OUPath"] = $OUPath
    }

    if ($ComputerName) {
        $JoinParams["NewName"] = $ComputerName
        Write-Output "Computer wird umbenannt zu: $ComputerName"
    }

    Add-Computer @JoinParams

    Write-Output ""
    Write-Output "Domain-Join erfolgreich!"
    Write-Output "  Domain : $DomainName"
    Write-Output "  OU     : $(if ($OUPath) { $OUPath } else { 'Standard (CN=Computers)' })"
    Write-Output ""
    Write-Output "Hinweis: Packer fuehrt nach diesem Schritt einen Neustart durch."

} catch {
    Write-Error "Domain-Join fehlgeschlagen: $_"
    exit 1
}
