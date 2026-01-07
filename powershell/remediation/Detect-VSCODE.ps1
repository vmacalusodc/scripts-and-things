$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"
$installationsFile = "$logDir\VSCodeInstallations.txt"
$minVersion = [version]"1.104.0"

try {
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Overwrite log file on each run
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting VSCode detection (all installations)" | Out-File -FilePath $logFile -Force -Encoding UTF8
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Minimum required version: $minVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8

    $allInstallations = @()
    $needsUpdate = $false

    # Method 1: Check registry for all installations
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking registry for all VSCode installations..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "Registry::HKEY_USERS\*\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($regPath in $registryPaths) {
        try {
            $vscodeRegs = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*Visual Studio Code*" -and $_.DisplayName -notlike "*Insiders*" }
            
            foreach ($vscodeReg in $vscodeRegs) {
                $installation = @{
                    DisplayName = $vscodeReg.DisplayName
                    Version = $null
                    Location = $null
                    Source = "Registry"
                    RegistryPath = $vscodeReg.PSPath
                }
                
                # Get version
                if ($vscodeReg.DisplayVersion) {
                    try {
                        $installation.Version = [version]$vscodeReg.DisplayVersion
                    }
                    catch {
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Could not parse version: $($vscodeReg.DisplayVersion)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                }
                
                # Get location
                if ($vscodeReg.InstallLocation) {
                    $possibleExe = Join-Path $vscodeReg.InstallLocation "Code.exe"
                    if (Test-Path $possibleExe) {
                        $installation.Location = $possibleExe
                    }
                }
                
                # Alternative: Check DisplayIcon path
                if (-not $installation.Location -and $vscodeReg.DisplayIcon) {
                    $iconPath = $vscodeReg.DisplayIcon -replace ',\d+$', ''
                    if (Test-Path $iconPath) {
                        $installation.Location = $iconPath
                    }
                }
                
                # Only add if we have both version and location
                if ($installation.Version -and $installation.Location) {
                    # Check if already added (avoid duplicates)
                    $alreadyExists = $allInstallations | Where-Object { $_.Location -eq $installation.Location }
                    if (-not $alreadyExists) {
                        $allInstallations += $installation
                    }
                }
            }
        }
        catch {
            # Some registry paths may not be accessible, silently continue
            continue
        }
    }

    # Method 2: Check all user profiles directly
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking all user profiles for VSCode..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }
    
    foreach ($userProfile in $userProfiles) {
        $vscodePath = Join-Path $userProfile.FullName "AppData\Local\Programs\Microsoft VS Code\Code.exe"
        
        if (Test-Path $vscodePath) {
            # Check if already found via registry
            $alreadyExists = $allInstallations | Where-Object { $_.Location -eq $vscodePath }
            
            if (-not $alreadyExists) {
                # Get version from file
                $fileVersion = (Get-ItemProperty $vscodePath).VersionInfo.FileVersion
                if ($fileVersion) {
                    $versionParts = $fileVersion -split '\.'
                    if ($versionParts.Count -ge 3) {
                        $parsedVersion = [version]"$($versionParts[0]).$($versionParts[1]).$($versionParts[2])"
                        
                        $installation = @{
                            DisplayName = "Visual Studio Code (User: $($userProfile.Name))"
                            Version = $parsedVersion
                            Location = $vscodePath
                            Source = "FileSystem"
                            RegistryPath = $null
                        }
                        
                        $allInstallations += $installation
                    }
                }
            }
        }
    }
    
    # Method 3: Check system-wide paths
    $systemPaths = @(
        "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
    )
    
    foreach ($path in $systemPaths) {
        if (Test-Path $path) {
            $alreadyExists = $allInstallations | Where-Object { $_.Location -eq $path }
            
            if (-not $alreadyExists) {
                $fileVersion = (Get-ItemProperty $path).VersionInfo.FileVersion
                if ($fileVersion) {
                    $versionParts = $fileVersion -split '\.'
                    if ($versionParts.Count -ge 3) {
                        $parsedVersion = [version]"$($versionParts[0]).$($versionParts[1]).$($versionParts[2])"
                        
                        $installation = @{
                            DisplayName = "Visual Studio Code (System)"
                            Version = $parsedVersion
                            Location = $path
                            Source = "FileSystem"
                            RegistryPath = $null
                        }
                        
                        $allInstallations += $installation
                    }
                }
            }
        }
    }

    # Report findings
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found $($allInstallations.Count) VSCode installation(s)" | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    if ($allInstallations.Count -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No VSCode installations found" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "VSCode not installed"
        
        # Clear installations file
        if (Test-Path $installationsFile) {
            Remove-Item $installationsFile -Force
        }
        
        exit 0  # Not installed, no action needed
    }

    # Write installations to file for remediation script
    $allInstallations | ConvertTo-Json | Out-File -FilePath $installationsFile -Force -Encoding UTF8
    
    # Check each installation
    foreach ($installation in $allInstallations) {
        $status = if ($installation.Version -lt $minVersion) { "NEEDS UPDATE" } else { "UP TO DATE" }
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$status] $($installation.DisplayName) - Version: $($installation.Version) - Location: $($installation.Location)"
        $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        if ($installation.Version -lt $minVersion) {
            $needsUpdate = $true
        }
    }

    # Determine exit code
    if ($needsUpdate) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - RESULT: At least one installation needs update" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "VSCode update needed for one or more installations"
        exit 1  # Needs update
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - RESULT: All installations are up to date" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "All VSCode installations are up to date"
        exit 0  # All up to date
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR in detection: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "Error during VSCode detection: $_"
    exit 0  # Don't remediate on error
}