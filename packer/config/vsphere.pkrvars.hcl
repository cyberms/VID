/*
    DESCRIPTION:
    VMware vSphere variables used for all builds.
    - Variables are use by the source blocks.
*/

// vSphere Credentials
vsphere_endpoint            = "vcenter.vdi-experts.de"
vsphere_username            = "administrator@vsphere.local"
vsphere_password            = "Password1,"
vsphere_insecure_connection = true

// vSphere Settings
vsphere_datacenter = "datacenter"
vsphere_cluster    = "cluster"
vsphere_datastore  = "datastore"
vsphere_network    = "internal"
vsphere_folder     = "templates"