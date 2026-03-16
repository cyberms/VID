<#
    .DESCRIPTION
    Minimales Test-Script fuer die Citrix VDA Installation.
    Kopiert den Installer via SMB (gleiche Env-Vars wie Haupt-Script) und
    fuehrt ihn dann mit den absoluten Minimalflags aus - genau wie in der
    Citrix-Doku als Basis-Befehl beschrieben.

    Kein /includeadditional, kein /exclude, kein Defender-Handling, keine
    Komponenten-Logik - reines Baseline-Testing ob der Installer laeuft.

    Tauscht temporaer windows-citrix-vda.ps1 aus:
      In windows.pkr.hcl, Step 7, scripts-Zeile aendern:
        scripts = ["${path.cwd}/scripts/windows/windows-citrix-vda-test.ps1"]
#>

$ErrorActionPreference = "Stop"
$VdaFileName = if ($env:VID_VDA_INSTALLER) { $env:VID_VDA_INSTALLER } else { "VDAWorkstationSetup_2511.exe" }
$LocalInstall = "C:\Windows\Temp\$VdaFileName"

Write-Output "=== VDA Minimal Test ==="
Write-Output "PowerShell: $($PSVersionTable.PSVersion)"
Write-Output "OS: $([System.Environment]::OSVersion.VersionString)"

# --- Installer suchen: lokal (vorherige Kopie) -> SMB -> CD-ROM ---
$VdaExe = $null

if (Test-Path $LocalInstall) {
    Write-Output "Installer bereits lokal vorhanden: $LocalInstall"
    $VdaExe = $LocalInstall
}

if (-not $VdaExe -and $env:VID_SMB_SERVER -and $env:VID_SMB_SHARE) {
    $uncShare  = "\\$($env:VID_SMB_SERVER)\$($env:VID_SMB_SHARE)"
    $vdaSource = "$uncShare\citrix\vda\$VdaFileName"
    Write-Output "Kopiere Installer von SMB: $vdaSource"
    try {
        try { & net use $uncShare /delete /yes 2>&1 | Out-Null } catch {}
        $out = & net use $uncShare /user:"$($env:VID_SMB_USERNAME)" "$($env:VID_SMB_PASSWORD)" /persistent:no 2>&1
        if ($LASTEXITCODE -ne 0) { throw "net use fehlgeschlagen: $out" }
        Copy-Item $vdaSource $LocalInstall -Force
        try { & net use $uncShare /delete /yes 2>&1 | Out-Null } catch {}
        Write-Output "Kopiert: $([Math]::Round((Get-Item $LocalInstall).Length / 1MB, 1)) MB"
        $VdaExe = $LocalInstall
    } catch {
        Write-Output "SMB fehlgeschlagen: $_"
    }
}

if (-not $VdaExe) {
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'CDRom' -and $_.IsReady }
    foreach ($d in $drives) {
        $c = Get-ChildItem $d.RootDirectory -Filter "VDAWorkstationSetup*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { $VdaExe = $c.FullName; Write-Output "Installer auf CD-ROM: $VdaExe"; break }
    }
}

if (-not $VdaExe) { throw "VDA-Installer nicht gefunden (SMB, CD-ROM)." }

Write-Output "Installer: $VdaExe ($([Math]::Round((Get-Item $VdaExe).Length / 1MB, 1)) MB)"

# --- Minimalaufruf (direkt aus Citrix-Doku, ohne jegliche Extras) ---
$installArgs = "/quiet /noreboot /enable_hdx_ports /logpath C:\Windows\Temp\CitrixVDAInstall"

Write-Output ""
Write-Output "Starte: $VdaExe $installArgs"
Write-Output "(Dauer: 10-20 Minuten erwartet)"
Write-Output ""

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName        = $VdaExe
$psi.Arguments       = $installArgs
$psi.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($psi)
$p.WaitForExit()
Write-Output "Exit Code: $($p.ExitCode)"

# --- Logs ausgeben ---
foreach ($dir in @("C:\Windows\Temp\CitrixVDAInstall", "C:\ProgramData\Citrix\XenDesktopSetup")) {
    if (Test-Path $dir) {
        Write-Output ""
        Write-Output "=== Logs: $dir ==="
        Get-ChildItem $dir -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | ForEach-Object {
                Write-Output "--- $($_.Name) (letzte 40 Zeilen) ---"
                Get-Content $_.FullName -ErrorAction SilentlyContinue | Select-Object -Last 40 |
                    ForEach-Object { Write-Output "  $_" }
            }
    } else {
        Write-Output "Log-Verzeichnis nicht gefunden: $dir"
    }
}

if ($p.ExitCode -notin @(0, 3, 8, 1641, 3010)) {
    throw "VDA-Installer fehlgeschlagen mit Exit Code $($p.ExitCode). Logs siehe oben."
}
Write-Output ""
Write-Output "VDA-Installer erfolgreich (Exit Code $($p.ExitCode))."
