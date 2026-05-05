<#
.SYNOPSIS
    VID DSC Configuration – OS Baseline (Layer 5)

.DESCRIPTION
    PowerShell Desired State Configuration für den VID OS-Baseline (Layer 5).
    Ersetzt das imperative windows-prepare.ps1 durch eine idempotente, auditierbare
    DSC-Konfiguration.

    Konfigurierte Bereiche:
      - TLS 1.0 / 1.1 deaktiviert (SCHANNEL)
      - System-Hibernation deaktiviert
      - Passwort läuft nie ab (lokale Admins + Build-User)
      - Schnellstart (Fast Startup) deaktiviert (VDA-Kompatibilität)
      - Windows Fehlerberichterstattung deaktiviert
      - Power Plan: High Performance
      - Windows-Suche (Indexer-Dienst) deaktiviert (VDI-Performance)
      - HKCU-Defaults für neue Benutzer (Default User Hive)

.NOTES
    VID Layer     : 5 – OS Baseline
    Maintainer    : VID-Team
    PSADT Version : n/a (native DSC, keine externen Module)
    DSC-Modus     : ApplyOnly (Packer-Build – kein Pull-Server)
    Created       : 2026-05-05
#>

Configuration VID-OSBaseline {
    param (
        [Parameter(Mandatory = $false)]
        [string]$BuildUsername = $env:BUILD_USERNAME
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node "localhost" {

        # ── LCM: ApplyOnly (kein Monitoring nach dem Build) ─────────────────────
        LocalConfigurationManager {
            RebootNodeIfNeeded   = $false
            ConfigurationMode    = "ApplyOnly"
            ActionAfterReboot    = "ContinueConfiguration"
            RefreshMode          = "Push"
        }


        # ════════════════════════════════════════════════════════════════════════
        # TLS 1.0 – Deaktivieren (Client + Server)
        # ════════════════════════════════════════════════════════════════════════

        Registry "TLS10_Client_Enabled" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }

        Registry "TLS10_Client_DisabledByDefault" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
            ValueName = "DisabledByDefault"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }

        Registry "TLS10_Server_Enabled" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }

        Registry "TLS10_Server_DisabledByDefault" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
            ValueName = "DisabledByDefault"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }


        # ════════════════════════════════════════════════════════════════════════
        # TLS 1.1 – Deaktivieren (Client + Server)
        # ════════════════════════════════════════════════════════════════════════

        Registry "TLS11_Client_Enabled" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }

        Registry "TLS11_Client_DisabledByDefault" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
            ValueName = "DisabledByDefault"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }

        Registry "TLS11_Server_Enabled" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }

        Registry "TLS11_Server_DisabledByDefault" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
            ValueName = "DisabledByDefault"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
            Force     = $true
        }


        # ════════════════════════════════════════════════════════════════════════
        # Hibernation – Deaktivieren
        # ════════════════════════════════════════════════════════════════════════

        Registry "Hibernate_HiberFileSizePercent" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            ValueName = "HiberFileSizePercent"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
        }

        Registry "Hibernate_HibernateEnabled" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            ValueName = "HibernateEnabled"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
        }


        # ════════════════════════════════════════════════════════════════════════
        # Fast Startup – Deaktivieren (notwendig für Citrix VDA Kompatibilität)
        # ════════════════════════════════════════════════════════════════════════

        Registry "FastStartup_Disabled" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
            ValueName = "HiberbootEnabled"
            ValueData = "0"
            ValueType = "Dword"
            Ensure    = "Present"
        }


        # ════════════════════════════════════════════════════════════════════════
        # Windows Fehlerberichterstattung (WER) – Deaktivieren
        # ════════════════════════════════════════════════════════════════════════

        Registry "WER_Disabled" {
            Key       = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
            ValueName = "Disabled"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
        }

        Registry "WER_DontShowUI" {
            Key       = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
            ValueName = "DontShowUI"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
        }


        # ════════════════════════════════════════════════════════════════════════
        # Power Plan – High Performance (VDI: kein Energiesparmodus)
        # ════════════════════════════════════════════════════════════════════════

        Script "PowerPlan_HighPerformance" {
            GetScript  = { return @{ Result = (powercfg /getactivescheme) } }
            TestScript = {
                $scheme = powercfg /getactivescheme
                # High Performance GUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                return $scheme -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            }
            SetScript  = {
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                Write-Verbose "Power Plan auf High Performance gesetzt."
            }
        }


        # ════════════════════════════════════════════════════════════════════════
        # Windows Search (Indexer) – Dienst deaktivieren (VDI-Performance)
        # ════════════════════════════════════════════════════════════════════════

        Service "WindowsSearch_Disabled" {
            Name        = "WSearch"
            StartupType = "Disabled"
            State       = "Stopped"
        }


        # ════════════════════════════════════════════════════════════════════════
        # Passwort läuft nie ab – lokale Administrator-Accounts
        # ════════════════════════════════════════════════════════════════════════

        Script "PasswordNeverExpires" {
            GetScript  = {
                $admin = (Get-LocalUser | Where-Object { $_.SID -like '*-500' }).Name
                return @{ Result = (Get-LocalUser -Name $admin).PasswordNeverExpires.ToString() }
            }
            TestScript = {
                $admin = (Get-LocalUser | Where-Object { $_.SID -like '*-500' }).Name
                $buildUser = $using:BuildUsername
                $adminOk = (Get-LocalUser -Name $admin).PasswordNeverExpires
                try {
                    $buildOk = (Get-LocalUser -Name $buildUser -ErrorAction Stop).PasswordNeverExpires
                } catch {
                    $buildOk = $true  # User existiert nicht – kein Problem
                }
                return ($adminOk -and $buildOk)
            }
            SetScript  = {
                $admin = (Get-LocalUser | Where-Object { $_.SID -like '*-500' }).Name
                Set-LocalUser -Name $admin -PasswordNeverExpires $true
                Write-Verbose "PasswordNeverExpires gesetzt: $admin"
                $buildUser = $using:BuildUsername
                try {
                    Set-LocalUser -Name $buildUser -PasswordNeverExpires $true
                    Write-Verbose "PasswordNeverExpires gesetzt: $buildUser"
                } catch {
                    Write-Verbose "Build-User '$buildUser' nicht gefunden – übersprungen."
                }
            }
        }


        # ════════════════════════════════════════════════════════════════════════
        # HKCU Default User – Explorer-Einstellungen für alle neuen Benutzer
        # (Hive wird temporär unter HKLM:\VID_DefaultUser gemountet)
        # ════════════════════════════════════════════════════════════════════════

        Script "DefaultUser_ExplorerSettings" {
            GetScript  = { return @{ Result = "DefaultUser Hive Explorer-Check" } }
            TestScript = {
                # Prüfen ob bereits angewendet (Sentinel-Key)
                $sentinel = "HKLM:\SOFTWARE\VendorIndependenceDay\DSC\DefaultUserExplorer"
                return (Test-Path $sentinel)
            }
            SetScript  = {
                $hivePath  = "C:\Users\Default\NTUSER.DAT"
                $mountKey  = "HKLM:\VID_DefaultUser"
                $mountName = "VID_DefaultUser"

                # Hive mounten
                reg load "HKLM\$mountName" $hivePath | Out-Null
                Start-Sleep -Milliseconds 500

                $explorerKey = "$mountKey\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

                # Sicherstellen dass der Key existiert
                if (-not (Test-Path $explorerKey)) {
                    New-Item -Path $explorerKey -Force | Out-Null
                }

                # Versteckte Dateien anzeigen
                Set-ItemProperty -Path $explorerKey -Name "Hidden"                     -Value 1 -Type DWord
                # Dateiendungen anzeigen
                Set-ItemProperty -Path $explorerKey -Name "HideFileExt"                -Value 0 -Type DWord
                # Leere Laufwerke ausblenden: nein
                Set-ItemProperty -Path $explorerKey -Name "HideDrivesWithNoMedia"      -Value 0 -Type DWord
                # OneDrive Sync-Benachrichtigungen aus
                Set-ItemProperty -Path $explorerKey -Name "ShowSyncProviderNotifications" -Value 0 -Type DWord

                # Hive unmounten
                [gc]::Collect()
                Start-Sleep -Milliseconds 500
                reg unload "HKLM\$mountName" | Out-Null

                # Sentinel setzen (idempotent)
                $sentinelKey = "HKLM:\SOFTWARE\VendorIndependenceDay\DSC\DefaultUserExplorer"
                New-Item -Path $sentinelKey -Force | Out-Null
                Set-ItemProperty -Path $sentinelKey -Name "Applied" -Value (Get-Date -Format "yyyy-MM-dd HH:mm") -Type String

                Write-Verbose "Default User Explorer-Einstellungen gesetzt."
            }
        }


        # ════════════════════════════════════════════════════════════════════════
        # VID DSC Sentinel – Erfolgreiche Anwendung dokumentieren
        # ════════════════════════════════════════════════════════════════════════

        Registry "VID_DSC_Applied" {
            Key       = "HKLM:\SOFTWARE\VendorIndependenceDay\DSC"
            ValueName = "OSBaseline"
            ValueData = "Applied"
            ValueType = "String"
            Ensure    = "Present"
            DependsOn = @(
                "[Registry]TLS10_Client_Enabled",
                "[Registry]TLS11_Client_Enabled",
                "[Registry]Hibernate_HibernateEnabled",
                "[Registry]FastStartup_Disabled",
                "[Script]PasswordNeverExpires",
                "[Script]DefaultUser_ExplorerSettings"
            )
        }

    } # Node localhost
} # Configuration VID-OSBaseline
