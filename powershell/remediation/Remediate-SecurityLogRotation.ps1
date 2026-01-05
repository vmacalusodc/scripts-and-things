<#
.SYNOPSIS
    Configures Security event log for auto-backup rotation and maintains max 3 archives.
.DESCRIPTION
    Intune Remediation Script - Sets Security log to AutoBackup mode and removes old archives.
.NOTES
    Author: IT Admin
    Version: 1.0
#>

$logName = "Security"
$maxArchives = 3
$archivePath = "$env:SystemRoot\System32\Winevt\Logs"
$archivePattern = "Archive-Security-*.evtx"

# Optional: Set maximum log size (in bytes) - 100MB default
# Adjust this based on how frequently you want rotation to occur
$maxLogSizeBytes = 209715200  # 200 MB

$remediationNeeded = $false
$errors = @()

try {
    # Configure log mode to AutoBackup
    $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
    
    if ($log.LogMode -ne "AutoBackup") {
        Write-Output "Setting Security log to AutoBackup mode..."
        $log.LogMode = "AutoBackup"
        $remediationNeeded = $true
    }
    
    # Optionally set max log size
    if ($log.MaximumSizeInBytes -ne $maxLogSizeBytes) {
        Write-Output "Setting Security log max size to $([math]::Round($maxLogSizeBytes / 1MB)) MB..."
        $log.MaximumSizeInBytes = $maxLogSizeBytes
        $remediationNeeded = $true
    }
    
    if ($remediationNeeded) {
        $log.SaveChanges()
        Write-Output "Security log configuration updated successfully."
    }
    else {
        Write-Output "Security log already configured correctly."
    }
}
catch {
    $errors += "Failed to configure Security log: $($_.Exception.Message)"
}

# Clean up old archives, keeping only the most recent $maxArchives
try {
    $archives = Get-ChildItem -Path $archivePath -Filter $archivePattern -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending
    
    if ($archives.Count -gt $maxArchives) {
        $archivesToDelete = $archives | Select-Object -Skip $maxArchives
        
        Write-Output "Found $($archives.Count) archives. Removing $($archivesToDelete.Count) old archive(s)..."
        
        foreach ($archive in $archivesToDelete) {
            try {
                Remove-Item -Path $archive.FullName -Force -ErrorAction Stop
                Write-Output "Deleted: $($archive.Name)"
            }
            catch {
                $errors += "Failed to delete $($archive.Name): $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Output "Archive count is within limit: $($archives.Count)/$maxArchives"
    }
}
catch {
    $errors += "Failed to process archives: $($_.Exception.Message)"
}

# Report results
if ($errors.Count -gt 0) {
    Write-Output "`nErrors encountered:"
    $errors | ForEach-Object { Write-Output "  - $_" }
    exit 1
}

Write-Output "`nRemediation completed successfully."
exit 0
