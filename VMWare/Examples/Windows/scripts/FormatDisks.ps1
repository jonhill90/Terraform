# Define Vars
$tmp_dir = "$env:SystemDrive\Windows\temp"

# Logging
Function Write-Log($message, $level = "INFO") {
    $date_stamp = Get-Date -Format s
    $log_entry = "$date_stamp - $level - $message"
    if (-not (Test-Path -Path $tmp_dir)) {
        New-Item -Path $tmp_dir -ItemType Directory > $null
    }
    $log_file = "$tmp_dir\FormatDisks.log"
    Write-Host -Message $log_entry
    Add-Content -Path $log_file -Value $log_entry
}


Write-Log -message "Initalizing Raw Disk" # Need to add logical check here.
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Local Disk" -Confirm:$false
Write-Log -message "Disks Added"