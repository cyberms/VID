# # output "svda_IP" {
# #   value = vsphere_virtual_machine.*.*.default_ip_address
# # }

# # output "inventory" {
# #   description = "generated ansible inventory"
# #   value = templatefile("hosts.tmpl", {
# #     instances_windows_server = [for i, vm in vsphere_virtual_machine.vm_win_server.*.default_ip_address : {
# #       ip = vsphere_virtual_machine.vm_win_server[i].default_ip_address
# #       name = format("%s%02d", var.name_windows_server, i + 1)
# #     }]
# #     instances_windows_client = [for i, vm in vsphere_virtual_machine.vm_server_client.*.default_ip_address : {
# #       ip = vsphere_virtual_machine.vm_server_client[i].default_ip_address
# #       name = format("%s%02d", var.name_server_client, i + 1)
# #     }]
# #   })
# # }
