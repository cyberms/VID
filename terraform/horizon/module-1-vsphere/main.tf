# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 1: vSphere VMs für Horizon Connection Server
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
#
# Erstellt:
#   - var.cs_vm_count VMs für Horizon Connection Server (Primary + Replica)
#   - Domain Join + WinRM-Aktivierung via run_once_command_list
# ─────────────────────────────────────────────────────────────────────────────

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "ds" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ── Horizon Connection Server VMs ────────────────────────────────────────────
resource "vsphere_virtual_machine" "horizon_cs" {
  count            = var.cs_vm_count
  name             = "${var.cs_vm_name_prefix}-${format("%02d", count.index + 1)}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id
  folder           = var.vsphere_folder

  num_cpus = var.cs_num_cpus
  memory   = var.cs_memory_mb
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.net.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.cs_disk_size_gb
    eagerly_scrub    = false
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      windows_options {
        computer_name         = "${var.cs_vm_name_prefix}-${format("%02d", count.index + 1)}"
        workgroup             = "WORKGROUP"
        admin_password        = var.vm_admin_password
        auto_logon            = true
        auto_logon_count      = 1
        time_zone             = 110  # W. Europe Standard Time

        # Domain Join
        join_domain           = var.ad_domain
        domain_admin_user     = var.ad_join_user
        domain_admin_password = var.ad_join_password
        organizational_unit   = var.ad_ou_path

        # WinRM aktivieren für spätere Provisioner in Modul 2
        run_once_command_list = [
          "cmd.exe /c winrm quickconfig -q",
          "cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB=\"512\"}",
          "cmd.exe /c winrm set winrm/config @{MaxTimeoutms=\"1800000\"}",
          "cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted=\"true\"}",
          "cmd.exe /c winrm set winrm/config/service/auth @{Basic=\"true\"}",
          "cmd.exe /c netsh advfirewall firewall add rule name=\"WinRM HTTP\" protocol=TCP dir=in localport=5985 action=allow",
        ]
      }

      network_interface {
        ipv4_address    = var.cs_ip_addresses[count.index]
        ipv4_netmask    = tonumber(split("/", var.cs_netmask)[1])
      }
      ipv4_gateway = var.cs_gateway
      dns_server_list = var.cs_dns_servers
    }
  }

  lifecycle {
    ignore_changes = [
      clone[0].template_uuid,
      annotation,
    ]
  }
}
