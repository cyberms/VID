# =============================================================================
# windows-domain-join.ps1
# Vendor Independence Day (VID) – Active Directory Domain Join
#
# Nimmt die Packer-Build-VM in die AD auf und legt den Computer-Account
# in der definierten OU ab.
#
# Wird als Packer-Provisioner ausgeführt, NACH Windows Updates
# und VOR der Citrix VDA Installation.
#
# Parameter werden von Packer als Umgebungsvariablen übergeben.
# =============================================================================

param(
    [string]$DomainName     = $env:PKR_VAR_domain_name,
    [string]$DomainUser     = $env:PKR_VAR_domain_join_username,
    [string]$DomainPassword = $env:PKR_VAR_domain_join_password,
    [string]$OUPath         = $env:PKR_VAR_domain_join_ou
)

# ── Eingaben prüfen ───────────────────────────────────────────────────────────
if (-not $DomainName -or -not $DomainUser -or -not $DomainPassword) {
    Write-Error "Domain-Join: Fehlende Pflichtparameter (DomainName, DomainUser, DomainPassword)."
    Write-Error "Bitte domain_name, domain_join_username und domain_join_password in build.pkrvars.hcl setzen."
    exit 1
}

Write-Output "=========================================================="
Write-Output "  VID – Active Directory Domain Join"
Write-Output "  Domain : $DomainName"
Write-Output "  OU     : $(if ($OUPath) { $OUPath } else { 'Standard (CN=Computers)' })"
Write-Output "  Account: $DomainUser"
Write-Output "=========================================================="

# ── Secure Credential erstellen ───────────────────────────────────────────────
$SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
$Credential     = New-Object System.Management.Automation.PSCredential($DomainUser, $SecurePassword)

# ── Aktuellen Status prüfen ───────────────────────────────────────────────────
$CurrentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
if ($CurrentDomain -eq $DomainName) {
    Write-Output "VM ist bereits Mitglied der Domain '$DomainName'. Kein Join notwendig."
    exit 0
}

Write-Output "Aktuelle Domain/Workgroup: $CurrentDomain"
Write-Output "Starte Domain-Join..."

# ── Domain-Join ───────────────────────────────────────────────────────────────
try {
    $JoinParams = @{
        DomainName  = $DomainName
        Credential  = $Credential
        Force       = $true
    }

    if ($OUPath) {
        $JoinParams["OUPath"] = $OUPath
    }

    Add-Computer @JoinParams

    Write-Output ""
    Write-Output "Domain-Join erfolgreich!"
    Write-Output "  Domain : $DomainName"
    Write-Output "  OU     : $(if ($OUPath) { $OUPath } else { 'Standard (CN=Computers)' })"
    Write-Output ""
    Write-Output "Hinweis: Packer führt nach diesem Schritt einen Neustart durch."

} catch {
    Write-Error "Domain-Join fehlgeschlagen: $_"
    exit 1
}
