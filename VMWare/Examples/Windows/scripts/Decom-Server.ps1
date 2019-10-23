param
(
    $ServerName,
    $Domain,
    $epoServer,
    $epouser,
    $epopass,
    $swServer

)

# Import Needed Modules
Import-Module ActiveDirectory

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


# Script Start

# Active Directory
$ADStatus =try{Get-ADComputer -Identity $ServerName -ErrorAction Stop}catch{}
if ($ADStatus) {
    Write-Host "AD Computer $ServerName exists removing."
    Remove-ADComputer -Identity $ServerName -Confirm:$False
}

# DNS
$ServerRecord = try{(Get-DnsServerResourceRecord -zonename "$Domain" -ComputerName "$Domain" -Name "$ServerName" -ErrorAction Stop)}catch{}
if ($ServerRecord){
Write-Host "A DNS Record for $ServerRecord.HostName was found."
Write-Host "Deleting record $ServerRecord.HostName ."
Remove-DnsServerResourceRecord -ZoneName "$Domain" -ComputerName "$Domain" -Name "$ServerName" -RRType A -Force
}

# McAfee
$McAfeeStatus = (((Get-ePoSystem -ComputerName $ServerName -epoServer $epoServer -epouser $epouser -epopass "$epopass") -split "`n") | Select-String 'System Name: [a-zA-Z0-9]')
if ($McAfeeStatus) {
    Write-host "Removing $ServerName from ePo."
    $RemoveStatus = (Remove-ePoSystem -ComputerName $ServerName -epoServer $epoServer -epouser $epouser -epopass "$epopass")
    Write-host $RemovalStatus.message
}

# SolarWinds
$SWStatus = (Get-SWNode -ComputerName $ServerName -swServer $swServer -CustomProperties True)
if ($SWStatus) {
    Write-Host "Removing $ServerName from SolarWinds."
    Remove-SWNode -ComputerName $ServerName -swServer $swServer
}