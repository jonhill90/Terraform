provider "aws" {
    region = "${var.region}"
}
data "aws_ami" "ec2-ami" {
  most_recent = true
  owners = ["${var.awsaccount}"]
  name_regex = "${var.amiregexid}"
  filter {
    name = "name"
    values = ["${var.amiregexname}"]
  }
}
# Create EC2 Instance
resource "aws_instance" "${var.servername}" {
    ami = "${data.aws_ami.ec2-ami.id}"
    iam_instance_profile = "${var.iaminstanceprofile}"
    instance_type = "${var.instancetype}"
    key_name = "${var.keyname}"
    source_dest_check = "true"
    subnet_id = "${var.subnetid}"
    tags {
        Owner = "${var.ownertag}"
        CreatedBy = "${var.createdbytag}"
        Name = "${var.servername}"
    }
    vpc_security_group_ids = ["${"${var.vpcsgid}"}"]
    user_data = "${file("Scripts/UserData.ps1")}"
  provisioner "local-exec" {
    when    = "destroy"
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\Decom-Server.ps1 -ServerName ${var.servername} -epoServer ${var.eposerver} -epouser ${var.epoadmin} -epopass ${var.domainpass} -swServer ${var.swServer}"
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
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\Start-PreConfig.ps1 -ServerName ${var.servername}"
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\Start-PostConfig.ps1 -ServerName ${var.servername} -swServer ${var.swServer} -Environment ${var.swEnvironment["${var.account}"]} -Vendor ${var.swVendor} -Community ${var.swCommunity}"
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\LCM-Configuration.ps1 -ServerName ${var.servername} -LCMOutputPath ${var.LCMOutputPath}"
  }
  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File .\\Scripts\\DSC-Configuration.ps1 -ServerName ${var.servername} -DSCOutputPath ${var.DSCOutputPath}"
  }
}
