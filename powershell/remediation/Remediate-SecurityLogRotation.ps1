# Remediation Script: Remediate-SecurityLogRotation.ps1
# Configures Security event log for auto-backup rotation and maintains max archives
# Logs results to C:\R3-IT\SecurityLogRotationRemediation.log

$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"

$eventLogName = "Security"
$maxArchives = 3
$maxLogSizeBytes = 201326592  # 192 MB
$eventLogArchivePath = "$env:SystemRoot\System32\Winevt\Logs"
$eventLogArchivePattern = "Archive-Security-*.evtx"

$divider = "-----------------------------------------------"
$today = Get-Date

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Use Generic List for log content
$logContent = [System.Collections.Generic.List[string]]::new(100)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logContent.Add("Security Event Log Rotation Remediation Log")
$logContent.Add("Run Time: $timestamp")
$logContent.Add("Computer: $env:COMPUTERNAME")
$logContent.Add($divider)
$logContent.Add("")
$logContent.Add("Settings:")
$logContent.Add("  Target Log Mode: AutoBackup")
$logContent.Add("  Target Max Size: $([math]::Round($maxLogSizeBytes / 1MB)) MB")
$logContent.Add("  Max Archives: $maxArchives")
$logContent.Add($divider)

# Track results
$configChanged = [System.Collections.Generic.List[string]]::new()
$archivesDeleted = [System.Collections.Generic.List[string]]::new()
$errors = [System.Collections.Generic.List[string]]::new()

# =============================================================================
# CONFIGURE EVENT LOG
# =============================================================================
$logContent.Add("")
$logContent.Add("%% EVENT LOG CONFIGURATION %%")
$logContent.Add("")

try {
    $log = Get-WinEvent -ListLog $eventLogName -ErrorAction Stop
    
    $logContent.Add("Current Configuration:")
    $logContent.Add("  Log Mode: $($log.LogMode)")
    $logContent.Add("  Max Size: $([math]::Round($log.MaximumSizeInBytes / 1MB)) MB")
    $logContent.Add("")
    
    $changesMade = $false
    
    # Check and update log mode
    if ($log.LogMode -ne "AutoBackup") {
        $logContent.Add("[ACTION] Setting log mode to AutoBackup...")
        $log.LogMode = "AutoBackup"
        $changesMade = $true
        $configChanged.Add("Log mode changed from '$($log.LogMode)' to 'AutoBackup'")
    }
    else {
        $logContent.Add("[OK] Log mode already set to AutoBackup")
    }
    
    # Check and update max size
    if ($log.MaximumSizeInBytes -ne $maxLogSizeBytes) {
        $oldSizeMB = [math]::Round($log.MaximumSizeInBytes / 1MB)
        $newSizeMB = [math]::Round($maxLogSizeBytes / 1MB)
        $logContent.Add("[ACTION] Setting max size to $newSizeMB MB...")
        $log.MaximumSizeInBytes = $maxLogSizeBytes
        $changesMade = $true
        $configChanged.Add("Max size changed from $oldSizeMB MB to $newSizeMB MB")
    }
    else {
        $logContent.Add("[OK] Max size already set to $([math]::Round($maxLogSizeBytes / 1MB)) MB")
    }
    
    # Save changes if any were made
    if ($changesMade) {
        $log.SaveChanges()
        $logContent.Add("")
        $logContent.Add("[OK] Configuration saved successfully")
    }
}
catch {
    $logContent.Add("[FAIL] Error configuring Security log: $($_.Exception.Message)")
    $errors.Add("Failed to configure Security log: $($_.Exception.Message)")
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# ARCHIVE CLEANUP
# =============================================================================
$logContent.Add("")
$logContent.Add("%% ARCHIVE CLEANUP %%")
$logContent.Add("")

$archives = Get-ChildItem -Path $eventLogArchivePath -Filter $eventLogArchivePattern -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending

$logContent.Add("Archive Location: $eventLogArchivePath")
$logContent.Add("Current Archive Count: $($archives.Count)")
$logContent.Add("Max Archives Allowed: $maxArchives")
$logContent.Add("")

if ($archives.Count -gt $maxArchives) {
    $archivesToKeep = $archives | Select-Object -First $maxArchives
    $archivesToDelete = $archives | Select-Object -Skip $maxArchives
    
    $logContent.Add("Archives to KEEP ($($archivesToKeep.Count)):")
    foreach ($archive in $archivesToKeep) {
        $sizeMB = [math]::Round($archive.Length / 1MB, 2)
        $logContent.Add("  [KEEP] $($archive.Name) ($sizeMB MB)")
    }
    
    $logContent.Add("")
    $logContent.Add("Archives to DELETE ($($archivesToDelete.Count)):")
    
    foreach ($archive in $archivesToDelete) {
        $sizeMB = [math]::Round($archive.Length / 1MB, 2)
        $logContent.Add("  Deleting: $($archive.Name) ($sizeMB MB)")
        
        try {
            Remove-Item -Path $archive.FullName -Force -ErrorAction Stop
            $logContent.Add("    [OK] Deleted successfully")
            $archivesDeleted.Add($archive.Name)
        }
        catch {
            $logContent.Add("    [FAIL] $($_.Exception.Message)")
            $errors.Add("Failed to delete $($archive.Name): $($_.Exception.Message)")
        }
    }
}
elseif ($archives.Count -eq 0) {
    $logContent.Add("[OK] No archive files exist yet")
}
else {
    $logContent.Add("[OK] Archive count ($($archives.Count)) is within limit ($maxArchives)")
    $logContent.Add("")
    $logContent.Add("Existing Archives:")
    foreach ($archive in $archives) {
        $sizeMB = [math]::Round($archive.Length / 1MB, 2)
        $age = [math]::Round(($today - $archive.LastWriteTime).TotalDays)
        $logContent.Add("  $($archive.Name) ($sizeMB MB, $age days old)")
    }
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# SUMMARY
# =============================================================================
$logContent.Add("")
$logContent.Add("%% SUMMARY %%")
$logContent.Add("")

if ($configChanged.Count -gt 0) {
    $logContent.Add("[CONFIGURED] $($configChanged.Count) setting(s) changed:")
    foreach ($item in $configChanged) {
        $logContent.Add("  * $item")
    }
    $logContent.Add("")
}

if ($archivesDeleted.Count -gt 0) {
    $logContent.Add("[DELETED] $($archivesDeleted.Count) archive(s) removed:")
    foreach ($item in $archivesDeleted) {
        $logContent.Add("  * $item")
    }
    $logContent.Add("")
}

if ($errors.Count -gt 0) {
    $logContent.Add("[ERRORS] $($errors.Count) error(s) occurred:")
    foreach ($item in $errors) {
        $logContent.Add("  * $item")
    }
    $logContent.Add("")
}

if ($configChanged.Count -eq 0 -and $archivesDeleted.Count -eq 0 -and $errors.Count -eq 0) {
    $logContent.Add("[OK] No changes needed - system was already compliant")
    $logContent.Add("")
}

$logContent.Add($divider)

# =============================================================================
# RESULT
# =============================================================================
if ($errors.Count -gt 0) {
    $logContent.Add("Result: PARTIAL FAILURE")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 1
}
elseif ($configChanged.Count -gt 0 -or $archivesDeleted.Count -gt 0) {
    $logContent.Add("Result: SUCCESS")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 0
}
else {
    $logContent.Add("Result: NO ACTION TAKEN")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 0
}