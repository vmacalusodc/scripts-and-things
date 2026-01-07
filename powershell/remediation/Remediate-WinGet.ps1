$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"
$excludeFile = "$logDir\WinGetExclude.txt"

# Function to remove progress bars and spinner lines from winget output
function Remove-ProgressBars {
    param([string]$text)
    $lines = $text -split "`r?`n"
    $filtered = $lines | Where-Object { 
        # Filter out download progress lines (KB/MB indicators)
        $_ -notmatch '^\s+[-]\s+.*\d+\s*(KB|MB)\s*/\s*\d+.*\s*(KB|MB)' -and
        # Filter out spinner/progress indicator lines
        $_ -notmatch '^\s*[-\\|/]\s*$' -and
        # Filter out lines with common progress bar characters
        $_ -notmatch '[\u2588\u2591\u2592\u2593]' -and
        # Filter out garbled progress characters
        $_ -notmatch '\u0393\u00FB\u00EA\u0393\u00FB\u00C6' -and
        # Keep lines with actual content
        $_.Trim() -ne ""
    }
    return ($filtered -join "`n")
}

try {
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Read exclusion list from file created by detection script
    $skipPackages = @()
    if (Test-Path $excludeFile) {
        $skipPackages = Get-Content $excludeFile | Where-Object { $_.Trim() -ne "" }
        # Overwrite log file on each run
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting remediation" | Out-File -FilePath $logFile -Force ####-Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Loaded exclusion list: $($skipPackages -join ', ')" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    }
    else {
        # Overwrite log file on each run
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting remediation" | Out-File -FilePath $logFile -Force ####-Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No exclusion file found, proceeding without exclusions" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    }

    $Winget = Get-ChildItem -Path (Join-Path -Path (Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps") -ChildPath "Microsoft.DesktopAppInstaller*_x64*\winget.exe") | Select-Object -First 1
    
    if (-not $Winget) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: Winget not found" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        Write-Error "Winget not found"
        exit 1
    }

    Write-Host "Getting list of available upgrades..."
    
    $upgradeOutput = &$winget upgrade --accept-source-agreements 2>&1 | Out-String
    $cleanUpgradeOutput = Remove-ProgressBars $upgradeOutput
    
    # Only show non-empty cleaned output to console
    if ($cleanUpgradeOutput.Trim() -ne "") {
        Write-Host $cleanUpgradeOutput
    }
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Available upgrades:" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    $cleanUpgradeOutput | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    
    # Check if winget found any packages at all
    if ($upgradeOutput -match "No installed package found|No applicable update found") {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No packages available for upgrade" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        Write-Host "No packages available for upgrade"
        exit 0
    }
    
    # Parse package IDs from the upgrade list
    $lines = $upgradeOutput -split "`r?`n"
    $packages = @()
    
    foreach ($line in $lines) {
        # Match lines that have version numbers (indicates a package with updates)
        if ($line -match '^\s*(.+?)\s+([\w\.\-]+)\s+(\d+[\.\d]+)\s+(\d+[\.\d]+)\s+\w+\s*$') {
            $packageId = $matches[2].Trim()
            if ($packageId -and $packageId -notmatch '^-+$') {
                $packages += $packageId
            }
        }
    }
    
    if ($packages.Count -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No packages found to upgrade" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        Write-Host "No packages found to upgrade"
        exit 0
    }
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found $($packages.Count) package(s) to upgrade" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    Write-Host "Found $($packages.Count) package(s) to upgrade"
    
    $successCount = 0
    $failCount = 0
    $skippedCount = 0
    
    foreach ($package in $packages) {
        if ($skipPackages -contains $package) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SKIPPED: $package (in exclusion list)" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
            Write-Host "Skipping: $package (in exclusion list)"
            $skippedCount++
            continue
        }
        
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Upgrading: $package" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        Write-Host "Upgrading: $package"
        
        $upgradeResult = &$winget upgrade --id $package --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
        $cleanUpgradeResult = Remove-ProgressBars $upgradeResult
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SUCCESS: $package" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
            Write-Host "  Success: $package"
        }
        else {
            $failCount++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - FAILED: $package (exit code: $LASTEXITCODE)" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Output: $cleanUpgradeResult" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
            Write-Warning "  Failed: $package (exit code: $LASTEXITCODE)"
            Write-Host "  Output: $cleanUpgradeResult"
        }
    }
    
    $summary = "Summary: $successCount successful, $failCount failed, $skippedCount skipped"
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $summary" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    Write-Host "`n$summary"
    
    # Exit 0 if we had any successes or only had skipped packages
    if ($successCount -gt 0 -or ($failCount -eq 0 -and $skippedCount -gt 0)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Remediation completed successfully" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        exit 0
    }
    elseif ($failCount -eq 0 -and $successCount -eq 0 -and $skippedCount -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No packages to upgrade" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        Write-Host "No packages to upgrade"
        exit 0
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Remediation failed" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
        exit 1
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: $_" | Out-File -FilePath $logFile -Append ####-Encoding UTF8
    Write-Error "Error during upgrade: $_"
    exit 1
}