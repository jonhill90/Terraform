provider "vsphere" {
  user           = "${var.vsadmin}"
  password       = "${var.vspass}"
  vsphere_server = "${var.vsserver["${var.account}"]}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.vsdatacenter}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vsdatastore["${var.account}"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = "${var.vsdatastorecluster["${var.account}"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "${var.vscomputecluster["${var.account}"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vsresourcepool["${var.account}"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vsnetwork["${var.account}"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vmtemplate["${var.account}"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_folder" "folder" {
  path = "${var.vsfolderpath["${var.account}"]}"
}

resource "vsphere_virtual_machine" "vm" {
  count                = "${var.vmcount}"
  name                 = "${var.name}-${var.account}${count.index + 1}"
  resource_pool_id     = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  folder               = "${var.vsfolder["${var.account}"]}"
  num_cpus             = "${var.vmcpucount}"
  memory               = "${var.vmmemory}"
  guest_id             = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type            = "${data.vsphere_virtual_machine.template.scsi_type}"

  wait_for_guest_net_routable = true

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  disk {
    label       = "disk1"
    size        = "${var.datadrivesize}"
    unit_number = 1
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    customize {
      windows_options {
        computer_name         = "${var.name}-${var.account}${count.index + 1}"
        join_domain           = "${var.domain["${var.account}"]}"
        domain_admin_user     = "${var.sadmin}"
        domain_admin_password = "${var.sapass}"
      }
      network_interface {}
    }
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\Decom-Server.ps1 -ServerName ${var.name}-${var.account}${count.index + 1} -epoServer ${var.eposerver} -epouser ${var.epoadmin} -epopass ${var.sapass} -swServer ${var.swServer}"
  }
  provisioner "file" {
    source      = "Scripts/FormatDisks.ps1"
    destination = "C:/Windows/Temp/FormatDisks.ps1"
    connection {
      type     = "winrm"
      host     = "${self.default_ip_address}"
      user     = "${var.sadmin}"
      password = "${var.sapass}"
      agent    = "false"
      https    = "true"
      port     = "5986"
      insecure = "false"
      timeout  = "10m"
    }
  }
  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = "${self.default_ip_address}"
      user     = "${var.sadmin}"
      password = "${var.sapass}"
      agent    = "false"
      https    = "true"
      port     = "5986"
      insecure = "false"
      timeout  = "10m"
    }
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\FormatDisks.ps1"
    ]
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\Start-PreConfig.ps1 -ServerName ${var.name}-${var.account}${count.index + 1}"
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\Start-PostConfig.ps1 -ServerName ${var.name}-${var.account}${count.index + 1} -swServer ${var.swServer} -Environment ${var.swEnvironment["${var.account}"]} -Vendor ${var.swVendor} -Community ${var.swCommunity}"
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\LCM-Configuration.ps1 -ServerName ${var.name}-${var.account}${count.index + 1} -LCMOutputPath ${var.LCMOutputPath}"
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\DSC-Configuration.ps1 -ServerName ${var.name}-${var.account}${count.index + 1} -DSCOutputPath ${var.DSCOutputPath}"
  }
}
