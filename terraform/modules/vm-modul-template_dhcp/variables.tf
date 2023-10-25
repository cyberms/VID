# VMware vSphere configuration
variable "vsphere_dc_name" {
  description = "vsphere datacenter name"
  type        = string
  default     = "Datacenter"
}
variable "vsphere_network" {
  description = "choose vsphere network"
  type        = string
  default     = "internal"
}
variable "vsphere_folder" {
  description = "vsphere vm folder"
  type        = string
  default     = "virtualmachines"
}
variable "vsphere_template" {
  description = "vsphere template"
  type        = string
  default     = "linux-ubuntu-server-20-04-lts"
    # windows-server-2022, windows-server-2019, windows_client_21H2, windows_client_2111
}
variable "vsphere_template_folder" {
  description = "vsphere template folder"
  type        = string
  default     = "templates"
}
variable "vsphere_datastore" {
  description = "choose vsphere datastore"
  type        = string
  default     = "nvme-datastore"
}

variable "vsphere_timezone" {
  description = "vsphere timezone"
  type        = number
  default     = 110
}

# Which Windows administrator password to set during vm customization
variable "winadmin_password" {
  description = "winadmin password"
  type        = string
  default     = "Password1"
}

# Server VDA settings
variable "vm_name" {
  description = "vm name for vm"
  type        = string
  default     = "NYC-SRV-001"
}
variable "vm_mem" {
  description = "memory for vm"
  type        = number
  default     = 8192
}
variable "vm_cpu_num" {
  description = "number of vcpu for vm"
  type        = number
  default     = 4
}
variable "vm_disk_size" {
  description = "size of disk for vm"
  type        = number
  default     = 40
}
