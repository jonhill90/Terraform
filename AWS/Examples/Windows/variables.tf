variable "region" {
    type = "string"
    default = "us-east-1"  
}

variable "servername" {
    type = "string"
    default = "__ServerName__"  
}

variable "awsaccount" {
    type = "string"
    default = "__AWS_Account_ID__" 
}

variable "amiregexid" {
    type = "string"
    default = "__AMI_RegEx_ID_Prefix__"
}

variable "amiregexname" {
    type = "string"
    default = "__AMI_RegEx_Name_Prefix__"
}

variable "iaminstanceprofile" {
    type = "string"
    default = "__iam_instance_profile__"  
}

variable "instancetype" {
    type = "string"
    default = "__instance_type__"  
}

variable "keyname" {
    type = "string"
    default = "__key_name__"  
}

variable "subnetid" {
    type = "string"
    default = "__subnet_id__"
  
}

variable "ownertag" {
    type = "string"
    default = "__Owner__"
  
}

variable "createdbytag" {
    type = "string"
    default = "__Created_By__"
}

variable "nametag" {
    type = "string"  
    default = "__ServerName__"
}

variable "vpcsgid" {
    type = "string"  
    default = "__vpc_security_group_ids__"
}

variable "sadmin" {
    type = "string"
    default = "__domainadmin__"  
}

variable "localadmin" {
    type = "string"
    default = "Administrator"  
}

variable "localpass" {
    type = "string"
    default = "__LocalPass__"  
}

variable "domain" {
    type = "map"
    default = {
        "Dev" = "__DevDomain__"
        "Test" = "__TestDomain__"
        "Prod" = "__ProdDomain__"
        "RND" = "__DevDomain__"
        "POC" = "__DevDomain__"
    }
}

variable "domainadminfull" {
    type = "string"
    default = "__domainadminfull__"  
}

variable "domainadmin" {
    type = "string"
    default = "__domainadmin__"  
}

variable "domainpass" {
    type = "string"
    default = "__domainpassword__"  
}

variable "eposerver" {
    type = "string"
    default = "__ePoServer__"  
}

variable "swServer" {
    type = "string"
    default = "__SWServer__"  
}

variable "swCompany" {
    type = "string"
    default = "__SWCompany__"  
}

variable "swTeam" {
    type = "string"
    default = "__SWTeam__"
}

variable "swEnvironment" {
    type = "map"
    default = {
        "Dev" = "Development"
        "Test" = "Test"
        "Prod" = "Production"
        "RND" = "Development"
    }
}

variable "swVendor" {
    type = "string"
    default = "__SWVendor__"  
}

variable "swCommunity" {
    type = "string"
    default = "__Community_String__"  
}

variable "LCMOutputPath" {
    type = "string"
    default = ".\\LCM"
}

variable "DSCOutputPath" {
    type = "string"
    default = ".\\DSC"
}

variable "DestinationOU" {
    type = "string"
    default = "__DestinationOU__"
}

variable "WSUSType" {
    type = "string"
    default = "__WSUS_Type__"
  
}

variable "WSUSGroup1" {
    type = "map"
    default = {
        "NON-CRITICAL" = "WSUS-NON-CRITICAL-SERVERS"
        "CRITICAL" = "WSUS-CRITICAL-SERVERS"
    }
}

variable "WSUSGroup2" {
    type = "map"
    default = {
        "Dev" = "WSUS-SERVERS-DEV"
        "Test" = "WSUS-SERVERS-TEST"
        "Prod" = "WSUS-SERVERS-PROD"
        "RND" = "WSUS-SERVERS-DEV"
    }
}