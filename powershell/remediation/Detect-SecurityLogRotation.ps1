<#
.SYNOPSIS
    Detects if Security event log is configured for auto-backup rotation with max 3 archives.
.DESCRIPTION
    Intune Detection Script - Returns exit code 1 if remediation is needed, 0 if compliant.
.NOTES
    Author: IT Admin
    Version: 1.0
#>

$logName = "Security"
$maxArchives = 3
$archivePath = "$env:SystemRoot\System32\Winevt\Logs"
$archivePattern = "Archive-Security-*.evtx"

try {
    # Check if log is set to AutoBackup mode
    $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
    
    if ($log.LogMode -ne "AutoBackup") {
        Write-Output "Security log is not in AutoBackup mode. Current mode: $($log.LogMode)"
        exit 1
    }
    
    # Check archive count
    $archives = Get-ChildItem -Path $archivePath -Filter $archivePattern -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending
    
    if ($archives.Count -gt $maxArchives) {
        Write-Output "Too many archive files exist. Current count: $($archives.Count), Max allowed: $maxArchives"
        exit 1
    }
    
    Write-Output "Security log rotation is properly configured. Mode: AutoBackup, Archives: $($archives.Count)/$maxArchives"
    exit 0
}
catch {
    Write-Output "Error checking Security log configuration: $($_.Exception.Message)"
    exit 1
}
