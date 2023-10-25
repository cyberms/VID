resource "vsphere_virtual_machine" "svda" {

  name             = var.vm_name
  folder           = var.vsphere_folder
  firmware         = data.vsphere_virtual_machine.template.firmware
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = var.vm_cpu_num
  memory           = var.vm_mem
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.vm_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      windows_options {
        computer_name    = var.vm_name
        admin_password   = var.winadmin_password
        auto_logon       = true
        auto_logon_count = 1
        time_zone        = var.vsphere_timezone
      }

      network_interface {}
    }
  }
}
