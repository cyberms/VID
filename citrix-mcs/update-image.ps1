<#
    .SYNOPSIS
    Aktualisiert das Master Image eines bestehenden Citrix DaaS MCS-Maschinenkatalogs.

    .DESCRIPTION
    Wird nach jedem Packer-Build aufgerufen, um das neue Image in einen
    bestehenden nicht-persistenten Katalog einzuspielen. Unterstützt zwei Stufen:

      Test-Deployment  : -CatalogName "W11-Test"
      Prod-Deployment  : -CatalogName "W11-Prod"  (nach erfolgreichem Test)

    Workflow:
      1. Authentifizierung gegen Citrix Cloud
      2. Neues Master Image validieren (vSphere-Pfad)
      3. Publish-ProvMasterVmImage → neues Image im Katalog veröffentlichen
      4. Warten bis die Publish-Task abgeschlossen ist
      5. Zusammenfassung: altes vs. neues Image, Anzahl VMs, Status

    Nicht-persistente Kataloge (Random/Discard):
      VMs erhalten das neue Image automatisch beim nächsten Boot.
      Kein manueller Eingriff, kein Maintenance Mode notwendig.

    .PARAMETER CitrixClientId
    Citrix Cloud Secure Client ID

    .PARAMETER CitrixClientSecret
    Citrix Cloud Secure Client Secret

    .PARAMETER CustomerId
    Citrix Cloud Customer ID

    .PARAMETER CatalogName
    Name des Maschinenkatalogs der aktualisiert werden soll (muss bereits existieren).

    .PARAMETER MasterImageVM
    Vollständiger XDHyp-Pfad zum neuen Master Image (vSphere Template + Snapshot), z.B.:
    "XDHyp:\Connections\vSphere-Connection\dc.datacenter\cluster.cluster\windows-desktop-11-pro-abc123.vm\packer-snapshot.snapshot"

    .PARAMETER WaitTimeoutMinutes
    Timeout in Minuten für die Publish-Task. Standard: 60 Minuten.

    .PARAMETER WhatIf
    Zeigt an, was passieren würde, ohne Änderungen vorzunehmen.

    .EXAMPLE
    # Test-Katalog aktualisieren (nach Packer-Build)
    .\update-image.ps1 `
        -CitrixClientId     "YOUR_CLIENT_ID" `
        -CitrixClientSecret "YOUR_CLIENT_SECRET" `
        -CustomerId         "YOUR_CUSTOMER_ID" `
        -CatalogName        "W11-Test" `
        -MasterImageVM      "XDHyp:\Connections\vSphere-euc-demo\dc.datacenter\cluster.cluster\windows-desktop-11-pro-abc123.vm\packer-snapshot.snapshot"

    .EXAMPLE
    # Produktion aktualisieren (nach erfolgreichem Test)
    .\update-image.ps1 `
        -CitrixClientId     "YOUR_CLIENT_ID" `
        -CitrixClientSecret "YOUR_CLIENT_SECRET" `
        -CustomerId         "YOUR_CUSTOMER_ID" `
        -CatalogName        "W11-Prod" `
        -MasterImageVM      "XDHyp:\Connections\vSphere-euc-demo\dc.datacenter\cluster.cluster\windows-desktop-11-pro-abc123.vm\packer-snapshot.snapshot"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CitrixClientId,
    [Parameter(Mandatory)][string]$CitrixClientSecret,
    [Parameter(Mandatory)][string]$CustomerId,
    [Parameter(Mandatory)][string]$CatalogName,
    [Parameter(Mandatory)][string]$MasterImageVM,
    [Parameter()]         [int]   $WaitTimeoutMinutes = 60,
    [Parameter()]         [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $PSScriptRoot "update-image-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry
}

function Wait-ProvTask {
    param([string]$TaskId, [int]$TimeoutMinutes = 60)
    $waited = 0
    do {
        Start-Sleep -Seconds 30
        $waited += 0.5
        $task = Get-ProvTask -TaskId $TaskId
        $pct  = if ($task.TaskExpectedDurationMins -gt 0) {
            [int](($waited / $task.TaskExpectedDurationMins) * 100)
        } else { "-" }
        Write-Log "  Task Status: $($task.TaskState) | Fortschritt: ${pct}% | Wartezeit: ${waited}min"
    } while ($task.TaskState -notin @("Finished", "Cancelled", "Error") -and $waited -lt $TimeoutMinutes)

    return $task
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Log "==================================================="
Write-Log " Citrix DaaS – Image Update (nicht-persistent)"
Write-Log "==================================================="
Write-Log " Katalog:     $CatalogName"
Write-Log " Neues Image: $MasterImageVM"
Write-Log " WhatIf:      $WhatIf"
Write-Log "==================================================="

# ─────────────────────────────────────────────────────────────────────────────
# 1. Citrix DaaS SDK laden
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [1] Citrix DaaS SDK laden ---"
$sdkModules = @(
    "Citrix.DaaS.SDK",
    "Citrix.Broker.Commands",
    "Citrix.MachineCreation.Commands",
    "Citrix.Host.Commands"
)
$missing = $sdkModules | Where-Object { -not (Get-Module -ListAvailable -Name $_) }
if ($missing) {
    Write-Log "Fehlende SDK-Module: $($missing -join ', ')" "ERROR"
    throw "Citrix DaaS Remote PowerShell SDK nicht installiert."
}
Import-Module Citrix.DaaS.SDK -Force
Write-Log "  SDK geladen."

# ─────────────────────────────────────────────────────────────────────────────
# 2. Authentifizierung
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [2] Authentifizierung ---"
Set-XDCredentials -CustomerId $CustomerId -APIKey $CitrixClientId -SecretKey $CitrixClientSecret -ProfileType CloudAPI
Write-Log "  Citrix Cloud Authentifizierung erfolgreich."

# ─────────────────────────────────────────────────────────────────────────────
# 3. Katalog und aktuelles Image prüfen
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [3] Katalog prüfen ---"

$catalog = Get-BrokerCatalog -Name $CatalogName -ErrorAction SilentlyContinue
if (-not $catalog) {
    Write-Log "Katalog '$CatalogName' nicht gefunden." "ERROR"
    Write-Log "Bitte zuerst deploy-citrix-mcs.ps1 ausführen, um den Katalog initial anzulegen." "ERROR"
    throw "Katalog nicht gefunden: $CatalogName"
}

# Sicherstellen dass der Katalog nicht-persistent ist
if ($catalog.AllocationType -ne "Random") {
    Write-Log "Katalog '$CatalogName' ist kein nicht-persistenter Katalog (AllocationType: $($catalog.AllocationType))." "WARN"
    Write-Log "Dieses Skript ist für nicht-persistente Kataloge (Random/Discard) ausgelegt." "WARN"
}

$provScheme  = Get-ProvScheme -ProvisioningSchemeName $CatalogName
$currentImage = $provScheme.MasterImageVM
$machines    = Get-BrokerMachine -CatalogName $CatalogName -ErrorAction SilentlyContinue

Write-Log "  Katalog:         $CatalogName (UID: $($catalog.Uid))"
Write-Log "  Allocation Type: $($catalog.AllocationType)"
Write-Log "  Anzahl VMs:      $($machines.Count)"
Write-Log "  Aktuelles Image: $currentImage"
Write-Log "  Neues Image:     $MasterImageVM"

if ($currentImage -eq $MasterImageVM) {
    Write-Log "  Das neue Image ist identisch mit dem aktuellen – kein Update notwendig." "WARN"
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Neues Image validieren
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [4] Neues Image validieren ---"

if (-not (Test-Path $MasterImageVM)) {
    Write-Log "Image-Pfad nicht gefunden: $MasterImageVM" "ERROR"
    Get-ChildItem -Path "XDHyp:\Connections\" | ForEach-Object {
        Write-Log "  Verfügbare Verbindung: $($_.Name)" "ERROR"
    }
    throw "Master Image nicht gefunden: $MasterImageVM"
}
Write-Log "  Image-Pfad validiert."

# ─────────────────────────────────────────────────────────────────────────────
# 5. Neues Image veröffentlichen
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "--- [5] Neues Image veröffentlichen ---"

if ($WhatIf) {
    Write-Log "  [WhatIf] Würde Publish-ProvMasterVmImage auf '$CatalogName' ausführen."
    Write-Log "  [WhatIf] Altes Image: $currentImage"
    Write-Log "  [WhatIf] Neues Image: $MasterImageVM"
} else {
    Write-Log "  Starte Image-Veröffentlichung..."
    $publishTask = Publish-ProvMasterVmImage `
        -ProvisioningSchemeName $CatalogName `
        -MasterImageVM          $MasterImageVM `
        -RunAsynchronously

    Write-Log "  Publish-Task gestartet: $($publishTask.TaskId)"
    Write-Log "  Warte auf Abschluss (Timeout: $WaitTimeoutMinutes Minuten)..."

    $completedTask = Wait-ProvTask -TaskId $publishTask.TaskId -TimeoutMinutes $WaitTimeoutMinutes

    if ($completedTask.TaskState -eq "Finished") {
        Write-Log "  Image erfolgreich veröffentlicht."
    } elseif ($completedTask.TaskState -eq "Error") {
        Write-Log "  Publish fehlgeschlagen: $($completedTask.ErrorCode) – $($completedTask.ErrorMessage)" "ERROR"
        throw "Image-Update fehlgeschlagen."
    } else {
        Write-Log "  Publish-Task endete mit Status: $($completedTask.TaskState)" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Zusammenfassung
# ─────────────────────────────────────────────────────────────────────────────

Write-Log "==================================================="
Write-Log " Image Update – Zusammenfassung"
Write-Log "==================================================="
Write-Log " Katalog:          $CatalogName"
Write-Log " Vorheriges Image:"
Write-Log "   $currentImage"
Write-Log " Neues Image:"
Write-Log "   $MasterImageVM"

if (-not $WhatIf) {
    $updatedScheme = Get-ProvScheme -ProvisioningSchemeName $CatalogName
    $imageMatch = $updatedScheme.MasterImageVM -eq $MasterImageVM
    Write-Log " Verifizierung:    $(if ($imageMatch) { 'OK – Image korrekt gesetzt' } else { 'WARNUNG – Image stimmt nicht überein!' })"
    Write-Log ""
    Write-Log " VMs im Katalog:   $($machines.Count)"
    Write-Log " VM-Update:        Nicht-persistente VMs erhalten das neue Image beim nächsten Boot."
    Write-Log "                   Laufende Sessions sind nicht betroffen."
}

Write-Log ""
if ($CatalogName -like "*Test*" -or $CatalogName -like "*test*") {
    Write-Log " Nächste Schritte:"
    Write-Log "   1. Test-VM neu starten und validieren (Citrix DaaS Console)"
    Write-Log "   2. Nach erfolgreichem Test Produktion aktualisieren:"
    Write-Log "      .\update-image.ps1 -CatalogName 'W11-Prod' -MasterImageVM '<gleicher Pfad>'"
} else {
    Write-Log " Nächste Schritte:"
    Write-Log "   1. VMs erhalten das neue Image automatisch beim nächsten Neustart"
    Write-Log "   2. Monitoring: Citrix DaaS Console → Machine Catalogs → $CatalogName"
}

Write-Log ""
Write-Log " Log: $LogFile"
Write-Log "==================================================="
Write-Log " Image Update abgeschlossen"
Write-Log "==================================================="
