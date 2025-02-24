param
(
    $ServerName
)

# Define Vars
$tmp_dir = "$env:SystemDrive\Windows\temp\Azure DevOps"


# Logging
Function Write-Log($message, $level = "INFO") {
    $date_stamp = Get-Date -Format s
    $log_entry = "$date_stamp - $level - $message"
    if (-not (Test-Path -Path $tmp_dir)) {
        New-Item -Path $tmp_dir -ItemType Directory > $null
    }
    $log_file = "$tmp_dir\PreConfiguration.log"
    Write-Verbose -Message $log_entry
    Add-Content -Path $log_file -Value $log_entry
}

Function Reboot-AndResume {
    Write-Log -message "adding script to run on next logon"
    $script_path = $script:MyInvocation.MyCommand.Path
    $ps_path = "$env:SystemDrive\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    if ($username -and $password) {
        $arguments = "$arguments -username `"$username`" -password `"$password`""
    }
    if ($verbose) {
        $arguments = "$arguments -Verbose"
    }

    $command = "$ps_path -ExecutionPolicy ByPass -File $script_path"
    $reg_key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $reg_property_name = $ConfigStep
    Set-ItemProperty -Path $reg_key -Name $reg_property_name -Value $command

    Write-Log -message "Checking for Administrator credentials."
    if ($username -and $password) {
        Write-Log -message "Credentials found."
        Write-Log -message "Username: $username" # Debug
        Write-Log -message "Password: $password" # Debug
        $reg_winlogon_path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $reg_winlogon_path -Name AutoAdminLogon -Value 1
        Set-ItemProperty -Path $reg_winlogon_path -Name AutoAdminLogonCount -Value 5
        Set-ItemProperty -Path $reg_winlogon_path -Name DefaultUserName -Value $username
        Set-ItemProperty -Path $reg_winlogon_path -Name DefaultPassword -Value $password
        Write-Log -message "rebooting server to continue $ConfigStep"
        shutdown /r /t 0
        break
    }
    else {
        Write-Log -message "Credentials not found."
        Write-Log -message "Terminating Script."
        Break
    }
}

Function Clear-AutoLogon {
    $reg_winlogon_path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Write-Log -message "clearing auto logon registry properties"
    Set-ItemProperty -Path $reg_winlogon_path -Name AutoAdminLogon -Value 0
    Remove-ItemProperty -Path $reg_winlogon_path -Name AutoAdminLogonCount -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $reg_winlogon_path -Name DefaultUserName -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $reg_winlogon_path -Name DefaultPassword -ErrorAction SilentlyContinue
}

Function Set-ComputerNameDisabled {
    # Configure the EC2Config service.
    Write-Log -message "Setting Config.xml to handle UserData."
    $ConfigFile = "C:\\Program Files\\Amazon\\Ec2ConfigService\\Settings\\Config.xml"
    $xml = [xml](get-content $ConfigFile)
    $xmlElement = $xml.get_DocumentElement()
    $xmlElementToModify = $xmlElement.Plugins

    foreach ($element in $xmlElementToModify.Plugin) {
        if ($element.name -eq "Ec2SetComputerName") {
            $element.State = "Disabled"
        }
    }
    $xml.Save($ConfigFile)
}

Write-Log -message "Starting script"

# Renaming Server
if ($env:COMPUTERNAME -ne $ServerName) {
    $ConfigStep = 'RenameServer'
    Write-Log -message "Renaming server to $ServerName"
    Rename-Computer -NewName $ServerName
    Write-Log -message "Rebooting to complete name change."
    Set-ComputerNameDisabled
    # Define Local Administrator credentials for Auto Login
    $username = 'Administrator'
    $password = '__admin_password__'
    Reboot-AndResume
}

# Joining to Domain
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
if ($domain -ne 'ad.YourDomain.us') {
    $ConfigStep = 'JoinDomain'
    # Define Domain Admin credentials for Domain Join and Auto Login
    $username = '__domain_admin__'
    $password = '__domain_admin_password__' | ConvertTo-SecureString -asPlainText -Force
    [PSCredential] $Credential = New-Object System.Management.Automation.PSCredential($username, $password)
    Write-Log -message "Joining Server to ad.YourDomain.us Domain."
    Add-Computer -DomainName "ad.YourDomain.us" -Credential $Credential -OUPath "OU=Servers,OU=Corporate,DC=ad,DC=YourDomain,DC=us"
    # Redefine password variable for Auto Login
    # Define Local Administrator credentials for Auto Login
    $username = 'Administrator'
    $password = '__admin_password__'
    Write-Log -message "Rebooting to finish domain join."
    Write-Log -message "Clearing AutoLogin credentials."
    Clear-AutoLogon
    shutdown /r /t 0
}