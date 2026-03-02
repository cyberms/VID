# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<#
    .DESCRIPTION
    Installs VMware Tools and runs re-attempts if the services fail on the first attempt.

    .SYNOPSIS
    - Packer requires that the VMware Tools service is running.
    - If the "VMware Tools Service" fails to start, the script initiates a reinstallation.

    .NOTES
    The below code is mostly based on the script within the following blog post by Owen Reynolds from scriptech.io.
    https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/
#>

$ErrorActionPreference = "Stop"

# Install VMWare Tools

Function Get-VMToolsInstalled {
    if (((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") | Where-Object { $_.GetValue( "DisplayName" ) -like "*VMware Tools*" } ).Length -gt 0) {
        [int]$Version = "32"
    }
    if (((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") | Where-Object { $_.GetValue( "DisplayName" ) -like "*VMware Tools*" } ).Length -gt 0) {
       [int]$Version = "64"
    }
    return $Version
}

# Automatisch das CD-Laufwerk finden, das setup.exe enthält (VMware Tools ISO).
# Ab VMware Tools 12.5.0 nur noch setup.exe (64-bit), setup64.exe entfällt.
# Laufwerksbuchstabe kann je nach Anzahl gemounteter ISOs variieren (D:, E:, F: ...).

Write-Output "Searching for VMware Tools installer on CD-ROM drives..."
$VMToolsDrive = $null
$VMToolsExe   = $null

Get-WmiObject Win32_CDROMDrive | ForEach-Object {
    $drive = $_.Drive
    if (Test-Path "$drive\setup.exe") {
        Write-Output "Found VMware Tools installer (setup.exe) at $drive"
        $VMToolsDrive = $drive
        $VMToolsExe   = "setup.exe"
    }
}

if (-not $VMToolsDrive) {
    Write-Error "VMware Tools installer not found on any CD-ROM drive. Ensure the VMware Tools ISO is attached."
    exit 1
}

Set-Location $VMToolsDrive

# Installation Attempt

Write-Output "Installing VMware Tools from $VMToolsDrive\$VMToolsExe ..."
Start-Process $VMToolsExe -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait -WindowStyle Hidden

# Check to see if the 'VMTools' service is in a 'Running' state.

$Running = $false
$iRepeat = 0

while (-not $Running -and $iRepeat -lt 5) {

  Start-Sleep -s 2
  Write-Output 'Checking VMware Tools service status...'
  $Service = Get-Service "VMTools" -ErrorAction SilentlyContinue
  $Servicestatus = $Service.Status

  if ($ServiceStatus -ne "Running") {
    $iRepeat++
  }
  else {
    $Running = $true
    Write-Output "VMware Tools service is in a running state."
  }
}

# If the service never enters the 'Running' state, reinstall VMware Tools.

if (-not $Running) {
  #Uninstall VMWare Tools
  Write-Output "Uninstalling VMware Tools..."
  if (Get-VMToolsInstalled -eq "32") {
    $GUID = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Like '*VMWARE Tools*' }).PSChildName
  }
  else {
    $GUID = (Get-ItemProperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Like '*VMWARE Tools*' }).PSChildName
  }

  # Uninstall VMware Tools based on 32-bit/64-bit install GUIDs captured via Get-VMToolsIsInstalled

  Start-Process -FilePath msiexec.exe -ArgumentList "/X $GUID /quiet /norestart" -Wait

  # Installation Attempt

  Write-Output "Reinstalling VMware Tools from $VMToolsDrive\$VMToolsExe ..."
  Start-Process $VMToolsExe -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait -WindowStyle Hidden

  # Check to see if the 'VMTools' service is in a 'Running' state.

Write-Output "Checking VMware Tools service status..."

$iRepeat = 0
while (-not $Running -and $iRepeat -lt 5) {
    Start-Sleep -s 2
    $Service = Get-Service "VMTools" -ErrorAction SilentlyContinue
    $ServiceStatus = $Service.Status

    if ($ServiceStatus -ne "Running") {
      $iRepeat++
    }
    else {
      $Running = $true
      Write-Output "VMware Tools service is in a running state."
    }
  }

  # If after the reinstall, the service is still not running, the installation is unsuccessful.

  if (-not $Running) {
    Write-Error "VMware Tools installation was unsuccessful."
    Pause
  }

}
