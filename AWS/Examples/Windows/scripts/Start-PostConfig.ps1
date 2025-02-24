param
(
    $ServerName,
    # McAfee ePo Parameters
    $epoServer,
    $epouser,
    $epopass,
    # SolarWinds Parameters
    $swServer,
    $Company,
    $Team,
    $Environment,
    $Vendor,
    $Community,
    $DestinationOU,
    $LocalAdmin,
    $LocalAdminPass,
    $vsServer,
    $WSUSGroup1,
    $WSUSGroup2
)
# Variables
$NodeName = $ServerName
$ComputerName = $ServerName

# Install PowerShell Modules
$ModuleList = ("PowerOrion", "SwisPowerShell", "ActiveDirectory")
$ModuleList | ForEach-Object {
    if (Get-Module -ListAvailable -Name $_) {
        Write-Host "Module $_ exists"
        Write-Host "Importing module $_"
        Import-Module -Name $_
    }
    else {
        Write-Host "Module $_ does not exist"
        Write-Host "Installing module $_"
        Install-Module -Name $_ -Confirm:$false -Force
        Write-Host "Importing module $_"
        Import-Module -Name $_
    }

}
# McAfee Functions
Function Get-ePoSystem {
    [CmdletBinding()]
    param
    (
        $ComputerName = (Read-Host "Enter system name."),
        $epoServer = (Read-Host "Enter ePo Server FQDN"),
        $epouser = (Read-Host "Enter username for $epoServer"),
        $epopass = (Read-Host "Enter password for $epoServer" -AsSecureString)
    
    )
    $epopass = $epopass | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = (New-Object System.Management.Automation.PSCredential($epouser, $epopass ))
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.DownloadString("$epoServer") | Out-Null
    $script:epoServer = $epoServer
    $script:Credentials = $Credentials
    
    $ComputerName | ForEach-Object {
        $uri = "$($epoServer)/remote/system.find?searchText=$_"
        Invoke-RestMethod -Uri $uri -Credential $Credentials
    }
    
}
Function Remove-ePoSystem {
    [CmdletBinding()]
    param
    (
        $ComputerName = (Read-Host "Enter system name."),
        $epoServer = (Read-Host "Enter ePo Server FQDN"),
        $epouser = (Read-Host "Enter username for $epoServer"),
        $epopass = (Read-Host "Enter password for $epoServer" -AsSecureString)
    )
    $epopass = $epopass | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = (New-Object System.Management.Automation.PSCredential($epouser, $epopass ))
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.DownloadString("$epoServer") | Out-Null
    $script:epoServer = $epoServer
    $script:Credentials = $Credentials
    
    $ComputerName | ForEach-Object {
        $uri = "$($epoServer)/remote/system.delete?names=$_"
        Invoke-RestMethod -Uri $uri -Credential $Credentials
    }
    
}

# SolarWinds Functions
function New-SWNode {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    [OutputType([int])]
    Param
    (
        #The IP address of the node to be added for monitoring
        $NodeName,
        $Company,
        $Team,
        $Environment,
        $Vendor,
        # SolarWinds Server
        $swServer,
        [int32]$engineid = 1,
        [int32]$status = 1,
        #Whether the device is Unmanaged or not (default = false)
        $UnManaged = $false,
        $DynamicIP = $false,
        $Allow64BitCounters = $true,
        $Community
    )
    Begin {
        #Nested Function
        $ComputerName = $NodeName
        Function Get-SWNode {
            [CmdletBinding()]
            param
            (
                $ComputerName,
                $swServer,
                $CustomProperties = "False"
            )
            $swis = Connect-Swis -Hostname $swServer -Trusted
            $NodeIDCheck = (get-orionNodeID -SwisConnection $swis -NodeName $ComputerName)
            
            if ($NodeIDCheck) {
                if ($CustomProperties -eq "True") {
                    Get-OrionNode -SwisConnection $swis -NodeID $NodeIDCheck -customproperties
                }
                Else {
                    Get-OrionNode -SwisConnection $swis -NodeID $NodeIDCheck
                }
            }
            Else {
                Write-host "$ComputerName not found." -ForegroundColor Red
            }
        }
        Write-Host "Starting $($myinvocation.mycommand)"
        $SwisConnection = Connect-Swis -Hostname $swServer -Trusted
        $swis = Connect-Swis -Hostname $swServer -Trusted
        $IPAddress = (Resolve-DnsName -Name $NodeName).IPAddress
        $SerialBug = $false
    
        $ipguid = [guid]::NewGuid()
    
        $newNodeProps = @{
            EntityType           = "Orion.Nodes";
            IPAddress            = $IPAddress;
            IPAddressGUID        = $ipGuid;
            Caption              = $NodeName;
            DynamicIP            = $DynamicIP;
            EngineID             = $engineid;
            Status               = $status;
            UnManaged            = $UnManaged;
            Allow64BitCounters   = $Allow64BitCounters;
            Location             = "";
            Contact              = "";
            NodeDescription      = "";
            Vendor               = "$Vendor";
            IOSImage             = "";
            IOSVersion           = "";
            SysObjectID          = "";
            MachineType          = "";
            VendorIcon           = "";
            # SNMP v2 specific
            ObjectSubType        = "SNMP";
            SNMPVersion          = 2;
            Community            = $Community;
            BufferNoMemThisHour  = "-2"; 
            BufferNoMemToday     = "-2"; 
            BufferSmMissThisHour = "-2"; 
            BufferSmMissToday    = "-2"; 
            BufferMdMissThisHour = "-2"; 
            BufferMdMissToday    = "-2"; 
            BufferBgMissThisHour = "-2"; 
            BufferBgMissToday    = "-2"; 
            BufferLgMissThisHour = "-2"; 
            BufferLgMissToday    = "-2"; 
            BufferHgMissThisHour = "-2"; 
            BufferHgMissToday    = "-2"; 
            PercentMemoryUsed    = "-2"; 
            TotalMemory          = "-2";                     
        }
        #next define the pollers for interfaces
        $PollerTypes = @("N.Status.ICMP.Native", "N.ResponseTime.ICMP.Native", "N.Details.SNMP.Generic", "N.Uptime.WMI.XP", "N.Cpu.WMI.Windows", "N.Memory.WMI.Windows")
        $CustomProperties = @{
            Company        = "$Company";
            Environment    = "$Environment";
            Production     = "$Team";
        }
        # Discover Storage on Node 
        Write-Host "Discovering Volumes on Node $NodeName"
        [array]$drives = Get-CimInstance Win32_Logicaldisk -ComputerName $NodeName -Filter "DriveType=3" | Select-Object Caption, VolumeName, VolumeSerialNumber, DriveLetter, DriveType;
    
        # Discover Memory on Node
        Write-Host "Discovering Virtual and Physical Memory on Node $NodeName"
        $MemoryList = @("Virtual Memory", "Physical Memory")  
    }
    Process {
        Write-Host "Adding $NodeName to Orion Database"
        If ($PSCmdlet.ShouldProcess("$IPAddress", "Add Node")) {
            $newNode = New-SwisObject $SwisConnection -EntityType "Orion.Nodes" -Properties $newNodeProps
            $nodeProps = Get-SwisObject $SwisConnection -Uri $newNode
            $newNodeUri = (Get-SWNode -ComputerName $NodeName -swServer $swServer -CustomProperties True).uri
            Set-SwisObject $SwisConnection -Uri $newNodeUri -Properties $CustomProperties
        }
            
        Write-Host "Node added with URI = $newNode"
        $NodeID = (get-orionNodeID -SwisConnection $swis -NodeName $NodeName)
        Write-Host "$NodeID"
    
        Write-Host "Now Adding pollers for the node..." 
        $nodeProps = Get-SwisObject $SwisConnection -Uri $newNode
        #Loop through all the pollers 
        foreach ($PollerType in $PollerTypes) {
            If ($PSCmdlet.ShouldProcess("$PollerTypes", "Add Poller")) {
                New-OrionPollerType -PollerType $PollerType -NodeProperties $nodeProps -SwisConnection $SwisConnection
            }          
        }
        foreach ($drive in $drives) {
            $VolumeExists = $Null
            $VolumeDescription = ''
            $VolumeCaption = ''
            if ($drive.DriveType -eq 3) {
                $VolumeIndex = $drives.IndexOf($drive) + 1
                $driveSerial = $drive.VolumeSerialNumber.ToLower()
                Switch ($SerialBug) {
                    True {
                        $driveSerialBug = $driveSerial -replace "^0", ""
                        $VolumeDescriptionBug = "$($drive.Caption)\ Label:$($drive.VolumeName)  Serial Number $($driveSerialBug)"
                        $VolumeCaptionBug = "$($drive.Caption)\ Label:$($drive.VolumeName) $($driveSerialBug)";
                        $VolumeDescription = $VolumeDescriptionBug
                        $VolumeCaption = $VolumeSerialBug
                        Write-Debug $VolumeDescription
                        Write-Debug $VolumeCaption
                    }
                    False {
                        $VolumeDescription = "$($drive.Caption)\ Label:$($drive.VolumeName)  Serial Number $($driveSerial)"
                        $VolumeCaption = "$($drive.Caption)\ Label:$($drive.VolumeName) $($driveSerial)";
                        Write-Debug $VolumeDescription
                        Write-Debug $VolumeCaption
                    }
                }
            }
            else {
                continue
            }
        }
        If ($SerialBug -eq $True) {
            $VolumeExists = Get-SwisData $swis "SELECT NodeID FROM Orion.Volumes WHERE NodeID=$NodeID AND VolumeDescription = $VolumeDescription"
        }
        If ($VolumeExists -eq $null) {
            $newVolProps = @{
                NodeID              = "$NodeID";
                VolumeIndex         = [int]$VolumeIndex;
                VolumeTypeID        = 4;
                VolumeSize          = "0";
                Type                = "Fixed Disk";
                Icon                = "FixedDisk.gif";
                Caption             = $VolumeCaption;
                VolumeDescription   = $VolumeDescription;
                PollInterval        = 120;
                StatCollection      = 15;
                RediscoveryInterval = 30;
                FullName            = $("$NodeName-$VolumeCaption")
            }
                                
            $newVolUri = New-SwisObject $swis -EntityType "Orion.Volumes" -Properties $newVolProps
            $VolProps = Get-SwisObject $swis -Uri $newVolUri
            Write-Debug $VolProps
            Write-Debug $newVolUri
            foreach ($pollerType in @('V.Status.SNMP.Generic', 'V.Details.SNMP.Generic', 'V.Statistics.SNMP.Generic')) {
                $poller = @{
                    PollerType    = $pollerType;
                    NetObject     = "V:" + $VolProps["VolumeID"];
                    NetObjectType = "V";
                    NetObjectID   = $VolProps["VolumeID"];
                }
                $pollerUri = New-SwisObject $swis -EntityType "Orion.Pollers" -Properties $poller
            }
            Start-Sleep 1
        }
        
        foreach ($Memory in $Memorylist) {
            $VolumeExists = $Null
            $VolumeDescription = "$Memory";
            Write-Debug "$VolumeDescription"
            $VolumeCaption = "$Memory";
            Write-Debug "$VolumeCaption"
            If ($Memory -like "Virtual memory") {
                $Type = "Virtual Memory" 
                $TypeID = 3
                                
            }
            If ($Memory -like "Physical memory") {
                $Type = "RAM"
                $TypeID = 2
            }
                            
            $TypeNoSpace = $Type.replace(" ", "")
            If ($SerialBug -eq $True) {
                $VolumeExists = Get-SwisData $swis "SELECT NodeID FROM Orion.Volumes WHERE NodeID=$NodeID AND VolumeDescription = $VolumeDescription"
            }
            If ($VolumeExists -eq $null) {
                $newVolProps = @{
                    NodeID              = "$NodeID";
                    Status              = 0;
                    VolumeIndex         = [int]$VolumeIndex;
                    VolumeTypeID        = $TypeID;
                    VolumeSize          = "0";
                    Type                = $Type;
                    Icon                = $("$TypeNoSpace.gif");
                    Caption             = $VolumeCaption;
                    VolumeDescription   = $VolumeDescription;
                    PollInterval        = 120;
                    StatCollection      = 15;
                    RediscoveryInterval = 30;
                    FullName            = $("$NodeName-$VolumeCaption")
                }
                $newVolUri = New-SwisObject $swis -EntityType "Orion.Volumes" -Properties $newVolProps
                $VolProps = Get-SwisObject $swis -Uri $newVolUri
                Write-Debug $VolProps
                Write-Debug $newVolUri
                foreach ($pollerType in @('V.Status.SNMP.Generic', 'V.Details.SNMP.Generic', 'V.Statistics.SNMP.Generic')) {
                    $poller = @{
                        PollerType    = $pollerType;
                        NetObject     = "V:" + $VolProps["VolumeID"];
                        NetObjectType = "V";
                        NetObjectID   = $VolProps["VolumeID"];
                    }
                    $pollerUri = New-SwisObject $swis -EntityType "Orion.Pollers" -Properties $poller
                }
                $VolumeIndex++
            }
        }
    
        # Trigger a PollNow on the node to cause other properties and stats to be filled in
        Invoke-SwisVerb $swis Orion.Nodes PollNow @("N:" + $NodeID)
    }
    End {
        Write-Output "$newNode"
        Write-Host "Finishing $($myinvocation.mycommand)"
    }
}
Function Get-SWNode {
    [CmdletBinding()]
    param
    (
        $ComputerName,
        $swServer,
        $CustomProperties
    )
    $swis = Connect-Swis -Hostname $swServer -Trusted
    $NodeIDCheck = (get-orionNodeID -SwisConnection $swis -NodeName $ComputerName)
    
    if ($NodeIDCheck) {
        if ($CustomProperties -eq "True") {
            Get-OrionNode -SwisConnection $swis -NodeID $NodeIDCheck -customproperties
        }
        Else {
            Get-OrionNode -SwisConnection $swis -NodeID $NodeIDCheck
        }
    }
    Else {
        Write-host "$ComputerName not found" -ForegroundColor Red
    }
}
Function Remove-SWNode {
    [CmdletBinding()]
    param
    (
        $ComputerName,
        $swServer
    )

    $swis = Connect-Swis -Hostname $swServer -Trusted
    $ComputerName | ForEach-Object {
        $NodeID = (get-orionNodeID -SwisConnection $swis -NodeName $ComputerName)
        if ($NodeID) {
            Remove-OrionNode -SwisConnection $swis -NodeID $NodeID
            Write-host "System $ComputerName with NodeID of $NodeID has been removed." -ForegroundColor Green
        }
        Else {
            Write-host "$ComputerName not found." -ForegroundColor Red
        }
    }
}
# Start Script
write-Host "Starting Post Configuration Script..."
$GetIp = (Get-ADComputer $ServerName -Properties *).IPv4Address
Write-Host "$GetIp"

# Move to Corporate DevOps OU
$ServerIdentity = (Get-ADComputer -Identity $ServerName)
$DestinationOU = "OU=DevOps,OU=Servers,OU=Corporate,DC=ad,DC=YourDomain,DC=us"

if ($ServerIdentity.DistinguishedName -ne "CN=$Servername,$DestinationOU") {
    Write-Host "Moving $ServerName to $DestinationOU"
    $ServerIdentity | Move-ADObject -TargetPath $DestinationOU
}



# Add server to WSUS AD Group (Critical or Non-Critical)
$ServerIdentity = (Get-ADComputer -Identity $ServerName)
$GroupIdentity1 = (Get-ADGroup -Identity $WSUSGroup1)
if (!(Get-ADGroupMember -Identity $WSUSGroup1 | ? { $_.name -eq $ServerName })) {
    write-host "Adding $ServerName to $WSUSGroup1"
    Add-ADGroupMember -Identity $GroupIdentity1 -Members $ServerIdentity
}

# Add server to WSUS AD Group (Dev, Test, Prod)
$ServerIdentity = (Get-ADComputer -Identity $ServerName)
$GroupIdentity2 = (Get-ADGroup -Identity $WSUSGroup2)
if (!(Get-ADGroupMember -Identity $WSUSGroup2 | ? { $_.name -eq $ServerName })) {
    write-host "Adding $ServerName to $WSUSGroup2"
    Add-ADGroupMember -Identity $GroupIdentity2 -Members $ServerIdentity
}

# Restart to Pickup Policy
$LocalAdmin = "$ServerName\$LocalAdmin"
$LocalAdminPass = $LocalAdminPass | ConvertTo-SecureString -AsPlainText -Force
$LocalCredentials = (New-Object System.Management.Automation.PSCredential($LocalAdmin, $LocalAdminPass ))
Start-Sleep -Seconds 120
Restart-Computer -ComputerName $ServerName -Credential $LocalCredentials -Wait
Start-Sleep -Seconds 60



# SolarWinds
$SWStatus = (Get-SWNode -ComputerName $ServerName -swServer $swServer -CustomProperties True)
if ($SWStatus) {
    Write-Host "The node $NodeName exists."
    Remove-SWNode -ComputerName $ServerName -swServer $swServer
    Write-Host "Node $NodeName removed."

    Write-Host "Creating node $NodeName"
    New-SWNode -NodeName $ServerName -swServer $swServer -Company $Company -Team $Team -Environment $Environment -Vendor $Vendor -Community $Community
    Write-Host "The node $NodeName has been created."
}
else {
    Write-Host "The node $NodeName does not exist."
    New-SWNode -NodeName $ServerName -swServer $swServer -Company $Company -Team $Team -Environment $Environment -Vendor $Vendor -Community $Community
}

