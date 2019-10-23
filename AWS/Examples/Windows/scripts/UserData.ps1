<powershell>
# Define Vars
$tmp_dir = "$env:SystemDrive\Windows\temp\Azure DevOps"
# Logging
Function Write-Log($message, $level = "INFO") {
    $date_stamp = Get-Date -Format s
    $log_entry = "$date_stamp - $level - $message"
    if (-not (Test-Path -Path $tmp_dir)) {
        New-Item -Path $tmp_dir -ItemType Directory > $null
    }
    $log_file = "$tmp_dir\AzureDevOps-UserData.log"
    Write-Verbose -Message $log_entry
    Add-Content -Path $log_file -Value $log_entry
}
Write-Log -message "Starting script."
# Configure WinRM
Write-Log -message "Setting PowerShell max envelope size to 2048."
Set-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb -Value 2048
Write-Log -message "Checking if winrm is running."
Write-Log -message "Running winrm quickconfig -force"
winrm quickconfig -force
winrm set winrm/config/service/Auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
Write-Log -message "WinRM Configuration complete."
Write-Log -message "Adding azdoba-prod IP Address to Hosts file."
Add-Content -Path $env:windir\System32\Drivers\Etc\Hosts. -Value "$AgentIP $AgentHostName"
Write-Log -message "Adding pacman-prod IP Address to Hosts file."
Add-Content -Path $env:windir\System32\Drivers\Etc\Hosts. -Value "$RepoIP $RepooHostName"
Write-Log -message "Userdata is complete."
</powershell>