# Remediate-TeamsClassic.ps1
# Removes ONLY Classic Teams (1.x versions) while preserving New Teams (24xxx/25xxx versions)
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"

try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    # Overwrite log file on each run
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting Classic Teams removal" | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    $removalAttempted = $false
    $errorMsgs = @()
    
    # Step 1: Kill Classic Teams processes (leave New Teams running)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Stopping Classic Teams processes..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    $teamsProcesses = Get-Process -Name "Teams" -ErrorAction SilentlyContinue
    foreach ($proc in $teamsProcesses) {
        try {
            # Check if this is Classic Teams by looking at the path
            if ($proc.Path -match "AppData\\Local\\Microsoft\\Teams") {
                # Check version to ensure it's Classic (1.x)
                $version = (Get-Item $proc.Path -ErrorAction SilentlyContinue).VersionInfo.FileVersion
                if ($version -match '^1\.') {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Stopping Classic Teams process (v$version): PID $($proc.Id)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                }
                else {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Keeping New Teams process (v$version): PID $($proc.Id)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
            }
        }
        catch {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Warning: Could not check process version for PID $($proc.Id)" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    
    Start-Sleep -Seconds 3
    
    # Step 2: Uninstall Machine-Wide Installer
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Uninstalling Machine-Wide Installer..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
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
        
        foreach ($app in $mwiApps) {
            try {
                $productCode = $app.PSChildName
                $displayName = $app.DisplayName
                $version = if ($app.DisplayVersion) { $app.DisplayVersion } else { "Unknown" }
                $installLocation = if ($app.InstallLocation) { $app.InstallLocation } else { "Not specified" }
                
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - UNINSTALLING CLASSIC MACHINE-WIDE INSTALLER:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Name: $displayName" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Version: $version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Install Location: $installLocation" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Product Code: {$productCode}" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Method: msiexec.exe /x" | Out-File -FilePath $logFile -Append -Encoding UTF8
                
                $uninstallArgs = "/x {$productCode} /qn /norestart"
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0) {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: SUCCESS (Exit Code: 0)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
                elseif ($process.ExitCode -eq 1605) {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: Product not found (Exit Code: 1605) - May have been already uninstalled" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
                elseif ($process.ExitCode -eq 1619) {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: Exit Code 1619 - MSI package not found (orphaned registry entry)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Attempting to remove orphaned registry entry..." | Out-File -FilePath $logFile -Append -Encoding UTF8
                    
                    # Remove the orphaned registry entry
                    try {
                        $regPath = $app.PSPath -replace 'Microsoft.PowerShell.Core\\Registry::', ''
                        Remove-Item -Path "Registry::$regPath" -Force -ErrorAction Stop
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Registry cleanup: SUCCESS - Orphaned entry removed" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                    catch {
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Registry cleanup: FAILED - $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
                        $errorMsgs += "Failed to remove orphaned registry entry: $_"
                    }
                }
                else {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: Exit Code $($process.ExitCode)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
                
                $removalAttempted = $true
            }
            catch {
                $errorMsg = "Failed to uninstall Machine-Wide Installer: $_"
                $errorMsgs += $errorMsg
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: $errorMsg" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
    }
    
    # Step 3: Remove per-user Classic Teams installations
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removing per-user Classic Teams installations..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }
    
    foreach ($userProfile in $userProfiles) {
        $teamsPath = Join-Path $userProfile.FullName "AppData\Local\Microsoft\Teams"
        $teamsExePath = Join-Path $teamsPath "current\Teams.exe"
        
        if (Test-Path $teamsExePath) {
            try {
                # Check version first
                $version = (Get-Item $teamsExePath).VersionInfo.FileVersion
                $productVersion = (Get-Item $teamsExePath).VersionInfo.ProductVersion
                $fileSize = [math]::Round((Get-Item $teamsExePath).Length / 1MB, 2)
                
                if ($version -match '^1\.') {
                    # This is Classic Teams - remove it
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - REMOVING CLASSIC TEAMS FROM USER PROFILE:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   User: $($userProfile.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Path: $teamsPath" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Version: $version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Product Version: $productVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Executable Size: $fileSize MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    
                    # Try to run Update.exe --uninstall first (cleaner method)
                    $updateExePath = Join-Path $teamsPath "Update.exe"
                    if (Test-Path $updateExePath) {
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Method: Running Update.exe --uninstall" | Out-File -FilePath $logFile -Append -Encoding UTF8
                        try {
                            $process = Start-Process -FilePath $updateExePath -ArgumentList "--uninstall -s" -Wait -PassThru -NoNewWindow -ErrorAction Stop
                            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Update.exe exit code: $($process.ExitCode)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                        }
                        catch {
                            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Update.exe failed: $_ (will remove folder manually)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                        }
                    }
                    else {
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Method: Manual folder removal (Update.exe not found)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                    
                    # Remove Teams folder
                    if (Test-Path $teamsPath) {
                        $folderSize = [math]::Round((Get-ChildItem -Path $teamsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Removing folder (Size: $folderSize MB): $teamsPath" | Out-File -FilePath $logFile -Append -Encoding UTF8
                        
                        Remove-Item -Path $teamsPath -Recurse -Force -ErrorAction Stop
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: SUCCESS - Folder removed" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                    else {
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: Folder already removed by Update.exe" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                    
                    $removalAttempted = $true
                }
                else {
                    # This is New Teams - leave it alone
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - NEW TEAMS FOUND (PRESERVING):" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   User: $($userProfile.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Path: $teamsPath" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Version: $version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Product Version: $productVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Action: SKIPPED (New Teams will not be removed)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
            }
            catch {
                $errorMsg = "Failed to remove Classic Teams for $($userProfile.Name): $_"
                $errorMsgs += $errorMsg
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: $errorMsg" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
    }
    
    # Step 4: Remove Classic Teams installer paths
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removing Classic Teams installer paths..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    $classicPaths = @(
        "${env:ProgramFiles}\Teams Installer",
        "${env:ProgramFiles(x86)}\Teams Installer"
    )
    
    foreach ($path in $classicPaths) {
        if (Test-Path $path) {
            try {
                $folderSize = [math]::Round((Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                $fileCount = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
                
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - REMOVING CLASSIC INSTALLER PATH:" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Path: $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Size: $folderSize MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Files: $fileCount" | Out-File -FilePath $logFile -Append -Encoding UTF8
                
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   Result: SUCCESS - Folder removed" | Out-File -FilePath $logFile -Append -Encoding UTF8
                $removalAttempted = $true
            }
            catch {
                $errorMsg = "Failed to remove installer path $path : $_"
                $errorMsgs += $errorMsg
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: $errorMsg" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
        else {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Path does not exist (already removed): $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    
    # Step 5: Clean up desktop shortcuts for Classic Teams
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Cleaning up Classic Teams shortcuts..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    foreach ($userProfile in $userProfiles) {
        $shortcuts = @(
            (Join-Path $userProfile.FullName "Desktop\Microsoft Teams.lnk"),
            (Join-Path $userProfile.FullName "Desktop\Microsoft Teams classic.lnk"),
            (Join-Path $userProfile.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk"),
            (Join-Path $userProfile.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams classic.lnk")
        )
        
        foreach ($shortcut in $shortcuts) {
            if (Test-Path $shortcut) {
                try {
                    Remove-Item -Path $shortcut -Force -ErrorAction Stop
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removed shortcut: $shortcut" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
                catch {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Warning: Could not remove shortcut: $shortcut" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
            }
        }
    }
    
    # Summary
    if ($removalAttempted) {
        if ($errorMsgs.Count -eq 0) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SUCCESS: Classic Teams removed successfully" | Out-File -FilePath $logFile -Append -Encoding UTF8
            Write-Host "Classic Teams removed successfully"
            exit 0
        }
        else {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PARTIAL SUCCESS: Removal attempted but some errors occurred:" | Out-File -FilePath $logFile -Append -Encoding UTF8
            foreach ($errorMsg in $errorMsgs) {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -   $errorMsg" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
            Write-Host "Classic Teams removal completed with some errors (see log)"
            exit 0  # Still exit 0 as we attempted removal
        }
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INFO: No Classic Teams found to remove" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "No Classic Teams found to remove"
        exit 0
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CRITICAL ERROR: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "Critical error during remediation: $_"
    exit 1
}
