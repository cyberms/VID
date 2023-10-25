data "vsphere_datacenter" "dc" {
  name = var.vsphere_dc_name
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "/${var.vsphere_dc_name}/vm/${var.vsphere_template_folder}/${var.vsphere_template}"
  datacenter_id = data.vsphere_datacenter.dc.id
}