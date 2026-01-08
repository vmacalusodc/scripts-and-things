# Detect-TeamsClassic.ps1
# Detects ONLY Classic Teams (1.x versions) and ignores New Teams (24xxx/25xxx versions)
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"

try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    # Overwrite log file on each run
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting Classic Teams detection" | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    $classicTeamsFound = $false
    $foundLocations = @()
    
    # Check 1: Machine-Wide Installer via Registry (faster than Win32_Product)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking for Machine-Wide Installer..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        $mwiApps = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_.DisplayName -like "*Teams Machine-Wide Installer*" -and 
                $_.DisplayName -notlike "*Add-in*"
            }
        
        if ($mwiApps) {
            foreach ($app in $mwiApps) {
                $classicTeamsFound = $true
                $displayName = $app.DisplayName
                $version = if ($app.DisplayVersion) { $app.DisplayVersion } else { "Unknown" }
                $installLocation = if ($app.InstallLocation) { $app.InstallLocation } else { "Not specified" }
                $productCode = $app.PSChildName
                
                $foundLocations += "CLASSIC Machine-Wide Installer: $displayName (v$version)"
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLASSIC TEAMS DETECTED:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Type: Machine-Wide Installer (MSI)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Name: $displayName" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Version: $version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Install Location: $installLocation" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Product Code: {$productCode}" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Registry Path: $($app.PSPath)" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
    }
    
    # Check 2: Per-user installations - ONLY Classic Teams (1.x versions)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking per-user installations..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }
    
    foreach ($userProfile in $userProfiles) {
        $teamsPath = Join-Path $userProfile.FullName "AppData\Local\Microsoft\Teams"
        $teamsCurrentPath = Join-Path $teamsPath "current"
        $teamsExePath = Join-Path $teamsCurrentPath "Teams.exe"
        
        if (Test-Path $teamsExePath) {
            try {
                $versionInfo = (Get-Item $teamsExePath).VersionInfo
                $fileVersion = $versionInfo.FileVersion
                $productVersion = $versionInfo.ProductVersion
                $fileSize = [math]::Round((Get-Item $teamsExePath).Length / 1MB, 2)
                $lastModified = (Get-Item $teamsExePath).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                
                # Parse version to determine if it's Classic (1.x) or New (24xxx/25xxx)
                if ($fileVersion -match '^1\.') {
                    # This is Classic Teams (1.x.x.x format)
                    $classicTeamsFound = $true
                    $foundLocations += "CLASSIC Teams (v$fileVersion) in user profile: $($userProfile.Name)"
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLASSIC TEAMS DETECTED:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Type: Per-User Installation" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   User Profile: $($userProfile.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Executable Path: $teamsExePath" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   File Version: $fileVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Product Version: $productVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   File Size: $fileSize MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Last Modified: $lastModified" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
                else {
                    # This is New Teams (24xxx.x.x.x or 25xxx.x.x.x format)
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - NEW TEAMS FOUND (WILL NOT REMOVE):" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Type: Per-User Installation" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   User Profile: $($userProfile.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Executable Path: $teamsExePath" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   File Version: $fileVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Product Version: $productVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   File Size: $fileSize MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Last Modified: $lastModified" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
            }
            catch {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR reading Teams info for $($userProfile.Name): $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Path attempted: $teamsExePath" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
    }
    
    # Check 3: Common installation paths for Classic Teams
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking common installation paths..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $classicPaths = @(
        "${env:ProgramFiles}\Teams Installer",
        "${env:ProgramFiles(x86)}\Teams Installer"
    )
    
    foreach ($path in $classicPaths) {
        if (Test-Path $path) {
            $classicTeamsFound = $true
            
            # Get details about the installer
            $teamsExe = Join-Path $path "Teams.exe"
            if (Test-Path $teamsExe) {
                try {
                    $version = (Get-Item $teamsExe).VersionInfo.FileVersion
                    $fileSize = [math]::Round((Get-Item $teamsExe).Length / 1MB, 2)
                    
                    $foundLocations += "CLASSIC Installer Path: $path (Teams.exe v$version)"
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLASSIC TEAMS INSTALLER DETECTED:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Type: Machine-Wide Installer Executable" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Folder Path: $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Executable: $teamsExe" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Version: $version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   File Size: $fileSize MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
                catch {
                    $foundLocations += "CLASSIC Installer Path: $path"
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLASSIC TEAMS INSTALLER DETECTED:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Folder Path: $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Note: Could not read Teams.exe details" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
            }
            else {
                $foundLocations += "CLASSIC Installer Path: $path (no Teams.exe found)"
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLASSIC TEAMS INSTALLER PATH DETECTED:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Folder Path: $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Note: Folder exists but Teams.exe not found" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
    }
    
    # Check 4: MSIX New Teams detection (for logging purposes - NOT marked for removal)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking for New Teams MSIX packages (for reference only)..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $windowsAppsPath = "C:\Program Files\WindowsApps"
    if (Test-Path $windowsAppsPath) {
        $msixTeams = Get-ChildItem -Path $windowsAppsPath -Directory -Filter "MSTeams_*" -ErrorAction SilentlyContinue
        
        if ($msixTeams) {
            foreach ($msixTeam in $msixTeams) {
                # Extract version from folder name (e.g., MSTeams_24215.1007.3082.1590_x64__8wekyb3d8bbwe)
                $folderName = $msixTeam.Name
                $versionMatch = $folderName -match "MSTeams_(\d+\.\d+\.\d+\.\d+)"
                $version = if ($versionMatch) { $matches[1] } else { "Unknown" }
                $architecture = if ($folderName -match "_(x64|x86|arm64)_") { $matches[1] } else { "Unknown" }
                $folderSize = [math]::Round((Get-ChildItem -Path $msixTeam.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - NEW TEAMS MSIX FOUND (WILL NOT REMOVE):" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Type: MSIX Package (New Teams)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Package Name: $folderName" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Version: $version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Architecture: $architecture" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Install Path: $($msixTeam.FullName)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Package Size: $folderSize MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
        else {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No New Teams MSIX packages found" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - WindowsApps folder not accessible" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    
    # Summary
    if ($classicTeamsFound) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - RESULT: Classic Teams IS installed (needs removal)" | Out-File -FilePath $logFile -Append -Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Classic Teams found in:" | Out-File -FilePath $logFile -Append -Encoding UTF8
        foreach ($location in $foundLocations) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   $location" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
        Write-Host "Classic Teams is installed in $($foundLocations.Count) location(s)"
        exit 1  # Needs remediation
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - RESULT: Classic Teams is NOT installed" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "Classic Teams is not installed"
        exit 0  # No action needed
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR in detection: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "Error during detection: $_"
    exit 0  # Don't remediate on error
}
