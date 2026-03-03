// VID - XenServer variables

variable "xenserver_host"     { type = string; description = "XenServer/Pool Master FQDN or IP" }
variable "xenserver_username" { type = string; sensitive = true; description = "XenServer username (default: root)" }
variable "xenserver_password" { type = string; sensitive = true; description = "XenServer password" }
variable "xenserver_sr"       { type = string; description = "Storage Repository name for VM disk" }
variable "xenserver_sr_iso"   { type = string; description = "Storage Repository name for ISO files" }
variable "xenserver_network"  { type = string; description = "XenServer network name for VM NIC" }

variable "vm_guest_os_family"  { type = string; default = "windows" }
variable "vm_guest_os_name"    { type = string; default = "desktop" }
variable "vm_guest_os_version" { type = string; default = "11" }
variable "vm_cpu_count"        { type = number; default = 2 }
variable "vm_mem_size"         { type = number; default = 4096 }
variable "vm_disk_size"        { type = number; default = 102400 }
variable "vm_boot_wait"        { type = string; default = "5s" }

variable "iso_file"           { type = string; description = "ISO filename on the XenServer SR" }

variable "build_username" { type = string; sensitive = true }
variable "build_password" { type = string; sensitive = true }

variable "scripts" { type = list(string); default = ["scripts/windows/windows-prepare.ps1"] }
variable "inline"  { type = list(string); default = ["Get-EventLog -LogName * | ForEach { Clear-EventLog -LogName $_.Log }"] }
