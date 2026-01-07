$logDir = "C:\R3-IT"
$logFile = "$logDir\VSCodeUpdate.log"
$installationsFile = "$logDir\VSCodeInstallations.txt"

try {
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Append to log (detection already created it)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ========================================" | Out-File -FilePath $logFile -Append -Encoding UTF8
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting VSCode remediation (all installations)" | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Read installations from file
    if (-not (Test-Path $installationsFile)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: Installations file not found" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Error "Installations file not found. Run detection script first."
        exit 1
    }

    $allInstallations = Get-Content $installationsFile -Raw | ConvertFrom-Json
    
    if ($allInstallations.Count -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No installations to update" | Out-File -FilePath $logFile -Append -Encoding UTF8
        Write-Host "No VSCode installations found"
        exit 0
    }

    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found $($allInstallations.Count) installation(s) to process" | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Note: VSCode processes are NOT stopped - installer will handle running instances
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - VSCode installer will handle any running instances" | Out-File -FilePath $logFile -Append -Encoding UTF8

    $successCount = 0
    $failCount = 0
    $skippedCount = 0

    foreach ($installation in $allInstallations) {
        $location = $installation.Location
        $currentVersion = $installation.Version
        $displayName = $installation.DisplayName
        
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ========================================" | Out-File -FilePath $logFile -Append -Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Processing: $displayName" | Out-File -FilePath $logFile -Append -Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Current version: $currentVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Location: $location" | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        # Determine installation type (user vs system)
        $installationType = "system"
        if ($location -like "*AppData\Local\Programs*") {
            $installationType = "user"
        }
        
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Installation type: $installationType" | Out-File -FilePath $logFile -Append -Encoding UTF8

        # Download appropriate installer
        if ($installationType -eq "user") {
            $installerUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
            $installerArgs = "/VERYSILENT /MERGETASKS=!runcode"
        }
        else {
            $installerUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
            $installerArgs = "/VERYSILENT /MERGETASKS=!runcode"
        }
        
        $installerPath = Join-Path $env:TEMP "VSCodeSetup_$($installationType).exe"
        
        try {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Downloading installer for $installationType install..." | Out-File -FilePath $logFile -Append -Encoding UTF8
            
            # Download installer
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
            
            if (-not (Test-Path $installerPath)) {
                throw "Installer download failed"
            }
            
            $installerSize = (Get-Item $installerPath).Length / 1MB
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Downloaded: $([math]::Round($installerSize, 2)) MB" | Out-File -FilePath $logFile -Append -Encoding UTF8
            
        }
        catch {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR downloading installer: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
            Write-Warning "Failed to download installer for $displayName"
            $failCount++
            
            # Clean up and continue to next installation
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            }
            continue
        }

        # Run installer
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Running installer..." | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        try {
            $process = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait -PassThru -NoNewWindow
            $exitCode = $process.ExitCode
            
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Installer exit code: $exitCode" | Out-File -FilePath $logFile -Append -Encoding UTF8
            
            if ($exitCode -eq 0) {
                # Verify new version
                Start-Sleep -Seconds 2
                if (Test-Path $location) {
                    $fileVersion = (Get-ItemProperty $location).VersionInfo.FileVersion
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SUCCESS: Updated to version $fileVersion" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    Write-Host "  Success: $displayName updated to $fileVersion"
                    $successCount++
                }
                else {
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - WARNING: Installation succeeded but cannot verify new version" | Out-File -FilePath $logFile -Append -Encoding UTF8
                    $successCount++
                }
            }
            else {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - FAILED: Installer returned exit code $exitCode" | Out-File -FilePath $logFile -Append -Encoding UTF8
                Write-Warning "  Failed: $displayName (exit code: $exitCode)"
                $failCount++
            }
        }
        catch {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR running installer: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
            Write-Warning "  Failed: $displayName - $_"
            $failCount++
        }
        finally {
            # Clean up installer
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Summary
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ========================================" | Out-File -FilePath $logFile -Append -Encoding UTF8
    $summary = "Summary: $successCount successful, $failCount failed, $skippedCount skipped"
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $summary" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "`n$summary"

    # Exit code
    if ($successCount -gt 0 -and $failCount -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - All updates completed successfully" | Out-File -FilePath $logFile -Append -Encoding UTF8
        exit 0
    }
    elseif ($successCount -gt 0 -and $failCount -gt 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Partial success: some updates failed" | Out-File -FilePath $logFile -Append -Encoding UTF8
        exit 0  # Partial success is still success
    }
    else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - All updates failed" | Out-File -FilePath $logFile -Append -Encoding UTF8
        exit 1
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR in remediation: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Error "Error during VSCode remediation: $_"
    exit 1
}