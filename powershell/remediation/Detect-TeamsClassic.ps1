# Detect-TeamsClassic.ps1
$logFile = "C:\R3-IT\TeamsClassic_Detection.log"

try {
    # Overwrite log file on each run
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting Teams Classic detection" | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    $teamsFound = $false
    $foundLocations = @()
    
    # Check 1: Machine-Wide Installer via Win32_Product (slow but thorough)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking Win32_Product..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $machineWideInstaller = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "*Teams Machine*" -and $_.Name -notlike "*Add-in*" }
    
    if ($machineWideInstaller) {
        $teamsFound = $true
        $foundLocations += "Machine-Wide Installer (Win32_Product): $($machineWideInstaller.Name)"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found: $($machineWideInstaller.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    
    # Check 2: Registry Uninstall entries (faster) - EXCLUDE Office Add-in
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking registry uninstall entries..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        $apps = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_.DisplayName -like "*Teams*" -and 
                $_.DisplayName -notlike "*New Teams*" -and
                $_.DisplayName -notlike "*Add-in*" -and
                $_.DisplayName -notlike "*Meeting Add-in*"
            }
        
        if ($apps) {
            foreach ($app in $apps) {
                $teamsFound = $true
                $foundLocations += "Registry: $($app.DisplayName) - $($app.PSChildName)"
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found in registry: $($app.DisplayName)" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
    }
    
    # Check 3: Per-user installations
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking per-user installations..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }
    
    foreach ($userProfile in $userProfiles) {
        $teamsUpdatePath = Join-Path $userProfile.FullName "AppData\Local\Microsoft\Teams\Update.exe"
        $teamsCurrentPath = Join-Path $userProfile.FullName "AppData\Local\Microsoft\Teams\current"
        
        if ((Test-Path $teamsUpdatePath) -or (Test-Path $teamsCurrentPath)) {
            $teamsFound = $true
            $foundLocations += "Per-user: $($userProfile.Name)"
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found per-user install: $($userProfile.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    
    # Check 4: Common installation paths
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking common installation paths..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $commonPaths = @(
        "${env:ProgramFiles}\Teams Installer",
        "${env:ProgramFiles(x86)}\Teams Installer"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $teamsFound = $true
            $foundLocations += "Path: $path"
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found path: $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    
    # Check 5: Winget detection
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking winget list..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $wingetPath = Get-ChildItem -Path (Join-Path -Path (Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps") -ChildPath "Microsoft.DesktopAppInstaller*_x64*\winget.exe") -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($wingetPath) {
        $wingetList = &$wingetPath list 2>&1 | Out-String
        if ($wingetList -match "Microsoft\.Teams\.Classic") {
            $teamsFound = $true
            $foundLocations += "Winget: Microsoft.Teams.Classic"
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found in winget list" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    
    # Log items being EXCLUDED from detection
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Items excluded from detection (kept installed):" | Out-File -FilePath $logFile -Append -Encoding UTF8
    $excludedItems = Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like "*Teams*Add-in*" -or $_.DisplayName -like "*Meeting Add-in*" }
    
    foreach ($item in $excludedItems) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   EXCLUDED: $($item.DisplayName)" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    
    # Summary
    if ($teamsFound) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - RESULT: Teams Classic IS installed" | Out-File -FilePath $logFile -Append -Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found in locations:" | Out-File -FilePath $logFile -Append -Encoding UTF8
        foreach ($location in $foundLocations) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   $location" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
        Write-Host "Teams Classic is installed in $($foundLocations.Count) location(s)"
        exit 1  # Needs remediation
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - RESULT: Teams Classic is NOT installed" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "Teams Classic is not installed"
        exit 0  # No action needed
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR in detection: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "Error during detection: $_"
    exit 0  # Don't remediate on error
}