# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1c, Modul 1: vSphere VMs für Cloud Connectors
# Status: SCAFFOLD – vor Produktiveinsatz vollständig testen!
#
# Erstellt:
#   - 2x Cloud Connector VMs (VID-CC-01, VID-CC-02)
#   - 1x Admin-VM (VID-TF-Admin) für Modul 2 WinRM-Provisioning
#
# Nach diesem Modul: Modul 2 (module-2-install) ausführen
# ─────────────────────────────────────────────────────────────────────────────

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ── Cloud Connector VMs ───────────────────────────────────────────────────────

resource "vsphere_virtual_machine" "cloud_connector" {
  count = var.cc_vm_count

  name             = "${var.cc_vm_name_prefix}-${format("%02d", count.index + 1)}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder

  num_cpus = var.cc_cpu_count
  memory   = var.cc_memory_mb
  guest_id = data.vsphere_virtual_machine.template.guest_id

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      windows_options {
        computer_name         = "${var.cc_vm_name_prefix}-${format("%02d", count.index + 1)}"
        join_domain           = var.domain
        domain_admin_user     = var.domain_admin_user
        domain_admin_password = var.domain_admin_password
        ou                    = var.cc_ou
        auto_logon            = true
        auto_logon_count      = 1
        # WinRM über run_once aktivieren (für Modul 2)
        run_once_command_list = [
          "cmd.exe /C winrm quickconfig -q",
          "cmd.exe /C winrm set winrm/config/service/auth @{Basic=\"true\"}",
          "cmd.exe /C netsh advfirewall firewall add rule name=\"WinRM\" dir=in action=allow protocol=TCP localport=5985"
        ]
      }

      network_interface {
        # DHCP – für statische IPs: ipv4_address/ipv4_netmask/ipv4_gateway setzen
      }
    }
  }

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  # Warten bis VMware Tools bereit (notwendig für Modul 2)
  wait_for_guest_net_timeout = 10
}

# ── Admin-VM (für WinRM-Provisioning in Modul 2) ─────────────────────────────

resource "vsphere_virtual_machine" "admin_vm" {
  name             = var.admin_vm_name
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder

  num_cpus = var.admin_cpu_count
  memory   = var.admin_memory_mb
  guest_id = data.vsphere_virtual_machine.template.guest_id

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      windows_options {
        computer_name         = var.admin_vm_name
        join_domain           = var.domain
        domain_admin_user     = var.domain_admin_user
        domain_admin_password = var.domain_admin_password
        auto_logon            = true
        auto_logon_count      = 3
        run_once_command_list = [
          "cmd.exe /C winrm quickconfig -q",
          "cmd.exe /C winrm set winrm/config/service/auth @{Basic=\"true\"}",
          "cmd.exe /C netsh advfirewall firewall add rule name=\"WinRM\" dir=in action=allow protocol=TCP localport=5985",
          # Terraform auf Admin-VM installieren (Chocolatey)
          "powershell.exe -Command \"Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))\""
        ]
      }

      network_interface {}
    }
  }

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  wait_for_guest_net_timeout = 10
}
