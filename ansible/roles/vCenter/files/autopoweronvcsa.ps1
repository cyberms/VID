# declare variables
param
(
  [string]$vcenter_hostname,
  [string]$vcenter_password,
  [string]$vcenter_username,
  [string]$vcenter_displayname,
  [string]$esxi_address
)
# connect to powercli
Connect-VIServer -Server $vcenter_hostname -User $vcenter_username -Password $vcenter_password | Out-Null
# enable VMHostStartpolicy on Host
Get-VMHost $esxi_address | Get-VMHostStartPolicy | Set-VMHostStartPolicy -Enabled:$true
# enable autostart on specific vm
Get-VM $vcenter_displayname | Get-VMStartPolicy | Set-VMStartpolicy -StartAction PowerOn -StartOrder 1 -StartDelay 30 -StopAction GuestShutDown -StopDelay 30
# move vm to vm folder
# Move-VM $vcenter_displayname -Destination virtualmachines