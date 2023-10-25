#===============================================================================
# VMware vSphere configuration
#===============================================================================

# vSphere username used to deploy the infrastructure
variable "vsphere_user" {
  description = "vsphere userlogon"
  type        = string
  default     = "administrator@vsphere.local"
}
variable "vsphere_password" {
  description = "vsphere user password"
  type        = string
  default     = "Password1,"
}
# vCenter IP or FQDN #
variable "vsphere_server" {
  description = "vsphere URL / IP address"
  type        = string
  default     = "vcenter.euc-lab.de"
}