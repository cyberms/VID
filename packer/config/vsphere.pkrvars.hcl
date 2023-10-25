/*
    DESCRIPTION:
    VMware vSphere variables used for all builds.
    - Variables are use by the source blocks.
*/

// vSphere Credentials
vsphere_endpoint            = "vcenter.euc-lab.de"
vsphere_username            = "administrator@vsphere.local"
vsphere_password            = "Password1,"
vsphere_insecure_connection = true

// vSphere Settings
vsphere_datacenter = "datacenter"
vsphere_cluster    = "cluster"
vsphere_datastore  = "nvme-datastore"
vsphere_network    = "external"
vsphere_folder     = "templates"