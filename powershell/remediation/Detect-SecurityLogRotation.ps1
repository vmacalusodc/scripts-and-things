# Detection Script: Detect-SecurityLogRotation.ps1
# Returns exit code 1 if remediation is needed (triggers remediation)
# Returns exit code 0 if compliant
# Logs results to C:\R3-IT\SecurityLogRotationDetection.log

$logDir = "C:\R3-IT"
$logFile = "$logDir\SecurityLogRotationDetection.log"

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
$logContent.Add("Security Event Log Rotation Detection Log")
$logContent.Add("Run Time: $timestamp")
$logContent.Add("Computer: $env:COMPUTERNAME")
$logContent.Add($divider)

# =============================================================================
# CONFIGURATION TARGETS
# =============================================================================
$logContent.Add("")
$logContent.Add("%% CONFIGURATION TARGETS %%")
$logContent.Add("")
$logContent.Add("  Log Mode: AutoBackup")
$logContent.Add("  Max Log Size: $([math]::Round($maxLogSizeBytes / 1MB)) MB")
$logContent.Add("  Max Archives: $maxArchives")
$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# CURRENT STATE
# =============================================================================
$logContent.Add("")
$logContent.Add("%% CURRENT STATE %%")
$logContent.Add("")

$complianceIssues = [System.Collections.Generic.List[string]]::new()

try {
    $log = Get-WinEvent -ListLog $eventLogName -ErrorAction Stop
    
    $logContent.Add("Security Event Log Configuration:")
    $logContent.Add("  Log Mode: $($log.LogMode)")
    $logContent.Add("  Max Size: $([math]::Round($log.MaximumSizeInBytes / 1MB)) MB ($($log.MaximumSizeInBytes) bytes)")
    $logContent.Add("  Log File: $($log.LogFilePath)")
    $logContent.Add("  Is Enabled: $($log.IsEnabled)")
    
    # Check log mode
    if ($log.LogMode -ne "AutoBackup") {
        $complianceIssues.Add("Log mode is '$($log.LogMode)' - should be 'AutoBackup'")
    }
    
    # Check log size
    if ($log.MaximumSizeInBytes -ne $maxLogSizeBytes) {
        $complianceIssues.Add("Max log size is $([math]::Round($log.MaximumSizeInBytes / 1MB)) MB - should be $([math]::Round($maxLogSizeBytes / 1MB)) MB")
    }
}
catch {
    $logContent.Add("  [ERROR] Failed to query Security log: $($_.Exception.Message)")
    $complianceIssues.Add("Unable to query Security log configuration")
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# ARCHIVE FILES
# =============================================================================
$logContent.Add("")
$logContent.Add("%% ARCHIVE FILES %%")
$logContent.Add("")

$archives = Get-ChildItem -Path $eventLogArchivePath -Filter $eventLogArchivePattern -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending

$logContent.Add("Archive Location: $eventLogArchivePath")
$logContent.Add("Archive Count: $($archives.Count) / $maxArchives max")
$logContent.Add("")

if ($archives.Count -gt 0) {
    $logContent.Add("Existing Archives:")
    foreach ($archive in $archives) {
        $sizeMB = [math]::Round($archive.Length / 1MB, 2)
        $age = [math]::Round(($today - $archive.LastWriteTime).TotalDays)
        $logContent.Add("  $($archive.Name)")
        $logContent.Add("    Size: $sizeMB MB | Modified: $($archive.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) ($age days ago)")
    }
}
else {
    $logContent.Add("  No archive files found")
}

if ($archives.Count -gt $maxArchives) {
    $excessCount = $archives.Count - $maxArchives
    $complianceIssues.Add("Too many archives: $($archives.Count) exist, max is $maxArchives ($excessCount to remove)")
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# SUMMARY
# =============================================================================
$logContent.Add("")
$logContent.Add("%% SUMMARY %%")
$logContent.Add($timestamp)
$logContent.Add("")

if ($complianceIssues.Count -eq 0) {
    $logContent.Add("[COMPLIANT] Security log rotation is properly configured")
    $logContent.Add("")
    $logContent.Add("  - Log Mode: AutoBackup")
    $logContent.Add("  - Max Size: $([math]::Round($maxLogSizeBytes / 1MB)) MB")
    $logContent.Add("  - Archives: $($archives.Count)/$maxArchives")
    $logContent.Add("")
    $logContent.Add($divider)
    $logContent.Add("Result: COMPLIANT")
    
    # Write log
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    # Output for Intune
    Write-Host $outputText
    exit 0
}
else {
    $logContent.Add("[NON-COMPLIANT] Issues detected:")
    $logContent.Add("")
    foreach ($issue in $complianceIssues) {
        $logContent.Add("  * $issue")
    }
    $logContent.Add("")
    $logContent.Add($divider)
    $logContent.Add("Result: NON-COMPLIANT [Issues: $($complianceIssues.Count)]")
    
    # Write log
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    # Output for Intune
    Write-Host $outputText
    exit 1
}
