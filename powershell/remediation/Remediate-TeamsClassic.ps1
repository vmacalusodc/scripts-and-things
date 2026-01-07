# Remediate-TeamsClassic.ps1
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$logDir = "C:\R3-IT"
$logFile = "$logDir\$scriptName.log"

try {
    # Overwrite log file on each run
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting Teams Classic remediation" | Out-File -FilePath $logFile -Force -Encoding UTF8
    
  
    # Step 1: Stop all Teams processes
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Stopping Teams processes..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    Get-Process -Name "Teams" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Step 2: Uninstall Machine-Wide Installer via MSI (EXCLUDE Office Add-in)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking for Machine-Wide Installer MSI..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        $teamsMSI = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_.DisplayName -like "*Teams Machine*" -and 
                $_.DisplayName -notlike "*Add-in*" -and
                $_.DisplayName -notlike "*Meeting Add-in*"
            }
        
        if ($teamsMSI) {
            $uninstallString = $teamsMSI.UninstallString
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found MSI: $($teamsMSI.DisplayName)" | Out-File -FilePath $logFile -Append -Encoding UTF8
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Uninstall string: $uninstallString" | Out-File -FilePath $logFile -Append -Encoding UTF8
            
            if ($uninstallString -match "msiexec") {
                # Extract product code
                if ($uninstallString -match "\{[A-F0-9\-]+\}") {
                    $productCode = $matches[0]
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Running: msiexec.exe /x $productCode /qn /norestart" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait -PassThru -NoNewWindow
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - MSI uninstall exit code: $($process.ExitCode)" | Out-File -FilePath $logFile -Append -Encoding UTF8
                }
            }
        }
    }
    
    # Step 3: Uninstall per-user installations
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Uninstalling per-user installations..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }
    
    foreach ($userProfile in $userProfiles) {
        $teamsUpdatePath = Join-Path $userProfile.FullName "AppData\Local\Microsoft\Teams\Update.exe"
        
        if (Test-Path $teamsUpdatePath) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Uninstalling for user: $($userProfile.Name)" | Out-File -FilePath $logFile -Append -Encoding UTF8
            $process = Start-Process -FilePath $teamsUpdatePath -ArgumentList "--uninstall -s" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Uninstall exit code for $($userProfile.Name): $($process.ExitCode)" | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }
    
    # Step 4: Remove leftover folders
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removing leftover folders..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    foreach ($userProfile in $userProfiles) {
        $teamsFolder = Join-Path $userProfile.FullName "AppData\Local\Microsoft\Teams"
        if (Test-Path $teamsFolder) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removing folder: $teamsFolder" | Out-File -FilePath $logFile -Append -Encoding UTF8
            Remove-Item -Path $teamsFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Remove common paths
    $commonPaths = @(
        "${env:ProgramFiles}\Teams Installer",
        "${env:ProgramFiles(x86)}\Teams Installer"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removing path: $path" | Out-File -FilePath $logFile -Append -Encoding UTF8
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Step 5: Clean up registry entries (EXCLUDE Office Add-in)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Cleaning registry entries..." | Out-File -FilePath $logFile -Append -Encoding UTF8
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $regPaths) {
        $teamsKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | 
            Where-Object { 
                $propName = (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).DisplayName
                $propName -like "*Teams Machine*" -and 
                $propName -notlike "*Add-in*" -and
                $propName -notlike "*Meeting Add-in*"
            }
        
        foreach ($key in $teamsKeys) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Removing registry key: $($key.PSPath)" | Out-File -FilePath $logFile -Append -Encoding UTF8
            Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Teams Classic remediation completed" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "Teams Classic remediation completed"
    exit 0
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR in remediation: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Error "Error during remediation: $_"
    exit 1
}