$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"
$excludeFile = "$logDir\WinGetExclude.txt"

# Function to remove progress bars and spinner lines from winget output
function Remove-ProgressBars {
    param([string]$text)
    $lines = $text -split "`r?`n"
    $filtered = $lines | Where-Object { 
        $line = $_
        # Keep the line if it doesn't match progress bar patterns
        # Progress bars typically have specific patterns
        -not ($line -match '^\s*[-\\|/]\s*$') -and  # Spinner lines
        -not ($line -match '^\s+[-─]\s+\d+\s*(KB|MB)\s*/\s*\d+\s*(KB|MB)') -and  # Download progress with sizes
        -not ($line -match '^[\s\u2588\u2591\u2592\u2593\u0393\u00FB\u00EA\u00C6]+\s+\d+\s*(KB|MB)\s*/\s*\d+\s*(KB|MB)\s*$')  # Pure progress bar lines
    }
    return ($filtered -join "`n")
}

try {
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Define packages to exclude (only place to update the list)
    $skipPackages = @(
        "Microsoft.Teams.Classic"
    )
    
    # Write exclusion list to file for remediation script
    $skipPackages | Out-File -FilePath $excludeFile -Force #-Encoding UTF8
    
    $Winget = Get-ChildItem -Path (Join-Path -Path (Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps") -ChildPath "Microsoft.DesktopAppInstaller*_x64*\winget.exe") | Select-Object -First 1
    
    if (-not $Winget) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Winget not found" | Out-File -FilePath $logFile -Force #-Encoding UTF8
        Write-Host "Winget not found"
        exit 0
    }

    # Overwrite log file on each run
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting detection" | Out-File -FilePath $logFile -Force #-Encoding UTF8
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Excluded packages: $($skipPackages -join ', ')" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    
    # Check for Intune-managed applications
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking for Intune-managed applications..." | Out-File -FilePath $logFile -Append #-Encoding UTF8
    $intuneApps = @()
    
    # Method 1: Check Intune registry keys
    $intuneRegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\*\*"
    )
    
    foreach ($regPath in $intuneRegPaths) {
        $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName } |
            Select-Object -ExpandProperty DisplayName -Unique
        
        foreach ($app in $apps) {
            if ($app -and $intuneApps -notcontains $app) {
                $intuneApps += $app
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Intune app found: $app" | Out-File -FilePath $logFile -Append #-Encoding UTF8
            }
        }
    }
    
    if ($intuneApps.Count -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   No Intune-managed apps found" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Total Intune-managed apps: $($intuneApps.Count)" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    }
    
    # Log winget list output (filtered)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - === WINGET LIST OUTPUT ===" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    $listOutput = &$winget list 2>&1 | Out-String
    $cleanListOutput = Remove-ProgressBars $listOutput
    $cleanListOutput | Out-File -FilePath $logFile -Append #-Encoding UTF8
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - === END WINGET LIST ===" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    
    # Check for conflicts between Intune and winget
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - === CHECKING FOR MANAGEMENT CONFLICTS ===" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    
    if ($intuneApps.Count -gt 0) {
        $conflicts = @()
        
        foreach ($intuneApp in $intuneApps) {
            # Check if this app name appears in winget list
            if ($listOutput -match [regex]::Escape($intuneApp)) {
                $conflicts += $intuneApp
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CONFLICT: '$intuneApp' is managed by both Intune and tracked by winget" | Out-File -FilePath $logFile -Append #-Encoding UTF8
            }
        }
        
        if ($conflicts.Count -eq 0) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No conflicts found between Intune and winget" | Out-File -FilePath $logFile -Append #-Encoding UTF8
        }
        else {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - WARNING: $($conflicts.Count) app(s) are managed by both Intune and winget" | Out-File -FilePath $logFile -Append #-Encoding UTF8
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Consider excluding these from winget updates to avoid conflicts" | Out-File -FilePath $logFile -Append #-Encoding UTF8
        }
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Skipping conflict check (no Intune apps detected)" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    }
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - === END CONFLICT CHECK ===" | Out-File -FilePath $logFile -Append #-Encoding UTF8

    # Get and log upgrade output
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - === WINGET UPGRADE OUTPUT ===" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    $upgradeOutput = &$winget upgrade --accept-source-agreements 2>&1 | Out-String
    $cleanUpgradeOutput = Remove-ProgressBars $upgradeOutput
    $cleanUpgradeOutput | Out-File -FilePath $logFile -Append #-Encoding UTF8
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - === END WINGET UPGRADE ===" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    
    # Remove skipped packages from output
    $lines = $upgradeOutput -split "`r?`n"
    $filteredLines = $lines | Where-Object {
        $line = $_
        $shouldInclude = $true
        foreach ($skip in $skipPackages) {
            if ($line -match [regex]::Escape($skip)) {
                $shouldInclude = $false
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Ignoring package in detection: $skip" | Out-File -FilePath $logFile -Append #-Encoding UTF8
                break
            }
        }
        $shouldInclude
    }
    
    $filteredOutput = $filteredLines -join "`n"
    
    # Check for upgrades (excluding skipped packages)
    if ($filteredOutput -match "No applicable update found|No installed package found") {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No upgrades available" | Out-File -FilePath $logFile -Append #-Encoding UTF8
        Write-Host "No upgrades available"
        exit 0
    }
    elseif ($filteredOutput -match '\d+[\.\d]+\s+\d+[\.\d]+\s+winget') {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Upgrades available (excluding ignored packages)" | Out-File -FilePath $logFile -Append #-Encoding UTF8
        Write-Host "Upgrades available (excluding ignored packages)"
        exit 1
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No upgrades available" | Out-File -FilePath $logFile -Append #-Encoding UTF8
        Write-Host "No upgrades available"
        exit 0
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Error in detection: $_" | Out-File -FilePath $logFile -Append #-Encoding UTF8
    Write-Host "Error checking for upgrades: $_"
    exit 0
}