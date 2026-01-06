# Remediation Script: Remediate-OutdatedDotNet.ps1
# Uninstalls end-of-life .NET runtimes using registry uninstall commands
# Logs results to C:\R3-IT\DotNetRemediation.log

$logDir = "C:\R3-IT"
$logFile = "$logDir\DotNetRemediation.log"

# Safety switches - set to $true to enable actual uninstallation
$PerformUninstall = $true

# Skip machines with Visual Studio or .NET SDK installed (likely developer machines)
$SkipDeveloperMachines = $true

# Skip runtimes that are currently loaded by running processes
$SkipLoadedRuntimes = $true

# Skip runtimes accessed within this many days (0 to disable)
$SkipRecentlyModifiedDays = 0

# .NET Support Policy Reference:
# https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core

# End of Life dates for .NET versions (update as needed)
$eolDates = @{
    "3.0" = [datetime]"2020-03-03"
    "3.1" = [datetime]"2022-12-13"
    "5.0" = [datetime]"2022-05-10"
    "6.0" = [datetime]"2024-11-12"
    "7.0" = [datetime]"2024-05-14"
    "8.0" = [datetime]"2026-11-10"
    "9.0" = [datetime]"2026-05-12"
}

# Dotnet root paths
$dotnetRoots = @(
    "C:\Program Files\dotnet",
    "C:\Program Files (x86)\dotnet"
)

$divider = "-----------------------------------------------"
$today = Get-Date

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$logContent = [System.Collections.Generic.List[string]]::new(100)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logContent.Add(".NET Runtime End-of-Life Remediation Log")
$logContent.Add("Run Time: $timestamp")
$logContent.Add("Computer: $env:COMPUTERNAME")
$logContent.Add($divider)
$logContent.Add("")
$logContent.Add("Settings:")
$logContent.Add("  PerformUninstall: $PerformUninstall")
$logContent.Add("  SkipDeveloperMachines: $SkipDeveloperMachines")
$logContent.Add("  SkipLoadedRuntimes: $SkipLoadedRuntimes")
$logContent.Add("  SkipRecentlyModifiedDays: $SkipRecentlyModifiedDays")
$logContent.Add($divider)

# =============================================================================
# DEVELOPER MACHINE CHECK
# =============================================================================
$isDeveloperMachine = $false
$devReasons = [System.Collections.Generic.List[string]]::new()

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Check for Visual Studio
foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        $vsEntries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.DisplayName -like "Microsoft Visual Studio 20*" -or
                $_.DisplayName -like "Visual Studio Community*" -or
                $_.DisplayName -like "Visual Studio Professional*" -or
                $_.DisplayName -like "Visual Studio Enterprise*"
            }
        if ($vsEntries) {
            $isDeveloperMachine = $true
            $devReasons.Add("Visual Studio installed")
            break
        }
    }
}

# Check for .NET SDK
foreach ($dotnetRoot in $dotnetRoots) {
    $sdkPath = Join-Path $dotnetRoot "sdk"
    if (Test-Path $sdkPath) {
        $sdkDirs = Get-ChildItem -Path $sdkPath -Directory -ErrorAction SilentlyContinue
        if ($sdkDirs.Count -gt 0) {
            $isDeveloperMachine = $true
            $devReasons.Add(".NET SDK installed")
            break
        }
    }
}

if ($isDeveloperMachine -and $SkipDeveloperMachines) {
    $logContent.Add("")
    $logContent.Add("[SKIP] DEVELOPER MACHINE DETECTED")
    $logContent.Add("  Reasons: $($devReasons -join '; ')")
    $logContent.Add("  Skipping remediation due to SkipDeveloperMachines = `$true")
    $logContent.Add("")
    $logContent.Add($divider)
    $logContent.Add("Result: SKIPPED (Developer Machine)")
    
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 0
}

# =============================================================================
# CHECK FOR LOADED RUNTIMES
# =============================================================================
$loadedRuntimePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

if ($SkipLoadedRuntimes) {
    try {
        $processes = Get-Process -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            try {
                $modules = $proc.Modules | Where-Object { 
                    $_.FileName -like "*\dotnet\shared\*" 
                }
                foreach ($module in $modules) {
                    if ($module.FileName -match '(.*\\dotnet\\shared\\[^\\]+\\[\d\.]+)\\') {
                        [void]$loadedRuntimePaths.Add($matches[1])
                    }
                }
            } catch {
                # Access denied - skip
            }
        }
    } catch {
        $logContent.Add("  Warning: Could not enumerate loaded modules")
    }
}

# =============================================================================
# FIND EOL .NET COMPONENTS IN REGISTRY
# =============================================================================
$logContent.Add("")
$logContent.Add("Scanning registry for EOL .NET components...")
$logContent.Add("")

$eolComponents = [System.Collections.Generic.List[hashtable]]::new()

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.DisplayName -like "Microsoft .NET Runtime*" -or
                $_.DisplayName -like "Microsoft ASP.NET Core*Shared Framework*" -or
                $_.DisplayName -like "Microsoft Windows Desktop Runtime*"
            }
        
        foreach ($entry in $entries) {
            if ($entry.DisplayName -and $entry.UninstallString) {
                # Extract version
                $version = ""
                $majorMinor = ""
                
                if ($entry.DisplayName -match '(\d+\.\d+\.\d+)') {
                    $version = $matches[1]
                    if ($version -match '^(\d+\.\d+)') {
                        $majorMinor = $matches[1]
                    }
                }
                
                # Check if EOL
                if ($majorMinor -and $eolDates.ContainsKey($majorMinor)) {
                    $eolDate = $eolDates[$majorMinor]
                    if ($today -gt $eolDate) {
                        # Determine the runtime path for loaded check
                        $runtimePath = ""
                        $arch = if ($entry.DisplayName -match '\(x86\)') { "x86" } else { "x64" }
                        $dotnetRoot = if ($arch -eq "x86") { "C:\Program Files (x86)\dotnet" } else { "C:\Program Files\dotnet" }
                        
                        if ($entry.DisplayName -like "*ASP.NET*") {
                            $runtimePath = "$dotnetRoot\shared\Microsoft.AspNetCore.App\$version"
                        } elseif ($entry.DisplayName -like "*Windows Desktop*") {
                            $runtimePath = "$dotnetRoot\shared\Microsoft.WindowsDesktop.App\$version"
                        } else {
                            $runtimePath = "$dotnetRoot\shared\Microsoft.NETCore.App\$version"
                        }
                        
                        # Check if loaded
                        $isLoaded = $loadedRuntimePaths.Contains($runtimePath)
                        
                        # Check last write time (not affected by enumeration)
                        $daysSinceWrite = -1
                        $daysSinceAccess = -1
                        if (Test-Path $runtimePath) {
                            $folderInfo = Get-Item $runtimePath -ErrorAction SilentlyContinue
                            if ($folderInfo) {
                                $daysSinceWrite = [math]::Round(($today - $folderInfo.LastWriteTime).TotalDays)
                                $daysSinceAccess = [math]::Round(($today - $folderInfo.LastAccessTime).TotalDays)
                            }
                        }
                        
                        $eolComponents.Add(@{
                            DisplayName = $entry.DisplayName
                            Version = $version
                            MajorMinor = $majorMinor
                            EolDate = $eolDate
                            UninstallString = $entry.UninstallString
                            RuntimePath = $runtimePath
                            IsLoaded = $isLoaded
                            DaysSinceWrite = $daysSinceWrite
                            DaysSinceAccess = $daysSinceAccess
                        })
                    }
                }
            }
        }
    }
}

# Remove duplicates (same component may appear in both registry paths)
$uniqueComponents = $eolComponents | 
    Sort-Object { $_.DisplayName } -Unique

$logContent.Add("Found $($uniqueComponents.Count) EOL component(s)")
$logContent.Add("")

# =============================================================================
# PERFORM UNINSTALLATION
# =============================================================================
$uninstalled = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($component in $uniqueComponents) {
    $logContent.Add("Processing: $($component.DisplayName)")
    
    # Check if loaded
    if ($SkipLoadedRuntimes -and $component.IsLoaded) {
        $logContent.Add("  [SKIP] Runtime is currently loaded by running process(es)")
        $skipped.Add("$($component.DisplayName) (loaded)")
        continue
    }
    
    # Check recent modification (using LastWriteTime to avoid false positives)
    if ($SkipRecentlyModifiedDays -gt 0 -and $component.DaysSinceWrite -ge 0 -and $component.DaysSinceWrite -le $SkipRecentlyModifiedDays) {
        $logContent.Add("  [SKIP] Runtime was modified $($component.DaysSinceWrite) days ago (threshold: $SkipRecentlyModifiedDays)")
        $logContent.Add("        Last write: $($component.DaysSinceWrite) days ago | Last access: $($component.DaysSinceAccess) days ago")
        $skipped.Add("$($component.DisplayName) (recent modification)")
        continue
    }
    
    if (-not $PerformUninstall) {
        $logContent.Add("  [DRY RUN] Would uninstall: $($component.UninstallString)")
        $skipped.Add("$($component.DisplayName) (dry run)")
        continue
    }
    
    # Parse and execute uninstall command
    $uninstallCmd = $component.UninstallString
    $logContent.Add("  UninstallString: $uninstallCmd")
    
    try {
        # Check for EXE bundle uninstaller (Package Cache)
        if ($uninstallCmd -match '^"?([^"]+\.exe)"?\s*/uninstall') {
            $exePath = $matches[1]
            $logContent.Add("  Detected EXE bundle uninstaller")
            
            if (Test-Path $exePath) {
                $logContent.Add("  Running: `"$exePath`" /uninstall /quiet /norestart")
                $process = Start-Process -FilePath $exePath -ArgumentList "/uninstall /quiet /norestart" -Wait -PassThru -NoNewWindow
                $logContent.Add("  EXE Exit Code: $($process.ExitCode)")
                
                # EXE bundle exit codes:
                # 0 = Success
                # 3010 = Success, reboot required
                # 1602 = User cancelled (shouldn't happen with /quiet)
                # 1603 = Fatal error
                
                if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                    Start-Sleep -Seconds 2
                    $stillExists = Test-Path $component.RuntimePath
                    if ($stillExists) {
                        $logContent.Add("  [WARN] EXE returned success but folder still exists, attempting folder cleanup...")
                        # Try to remove the folder directly
                        try {
                            Remove-Item -Path $component.RuntimePath -Recurse -Force -ErrorAction Stop
                            $logContent.Add("  [OK] Folder removed successfully")
                            $uninstalled.Add($component.DisplayName)
                        } catch {
                            $logContent.Add("  [FAIL] Could not remove folder: $($_.Exception.Message)")
                            $failed.Add("$($component.DisplayName) (folder locked)")
                        }
                    } else {
                        $logContent.Add("  [OK] Uninstalled successfully")
                        $uninstalled.Add($component.DisplayName)
                    }
                } else {
                    $logContent.Add("  [FAIL] EXE uninstall failed")
                    $failed.Add("$($component.DisplayName) (exit: $($process.ExitCode))")
                }
            } else {
                $logContent.Add("  [WARN] Bundle EXE not found at: $exePath")
                $logContent.Add("  Attempting direct folder removal...")
                # The bundle installer is gone, try to clean up the folder directly
                if (Test-Path $component.RuntimePath) {
                    try {
                        Remove-Item -Path $component.RuntimePath -Recurse -Force -ErrorAction Stop
                        $logContent.Add("  [OK] Folder removed successfully")
                        $uninstalled.Add($component.DisplayName)
                    } catch {
                        $logContent.Add("  [FAIL] Could not remove folder: $($_.Exception.Message)")
                        $failed.Add("$($component.DisplayName) (folder locked)")
                    }
                } else {
                    $logContent.Add("  [OK] Folder already gone")
                    $uninstalled.Add($component.DisplayName)
                }
            }
        }
        # Handle MsiExec uninstall strings (case-insensitive for hex characters)
        elseif ($uninstallCmd -match '(?i)MsiExec\.exe\s*/[IX]\{?([A-Fa-f0-9\-]+)\}?') {
            $productCode = $matches[1]
            $logContent.Add("  Parsed Product Code: {$productCode}")
            
            # Verify the product is actually installed before attempting uninstall
            $productCheck = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{$productCode}" -ErrorAction SilentlyContinue
            if (-not $productCheck) {
                $productCheck = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{$productCode}" -ErrorAction SilentlyContinue
            }
            
            if (-not $productCheck) {
                $logContent.Add("  [WARN] Product code not found in registry - may already be uninstalled or GUID mismatch")
            }
            
            # Run msiexec with silent uninstall flags and logging
            $msiLogFile = "$logDir\msi_uninstall_$($productCode).log"
            $msiArgs = "/X{$productCode} /qn /norestart /l*v `"$msiLogFile`""
            $logContent.Add("  Running: msiexec.exe $msiArgs")
            
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
            
            $logContent.Add("  MSI Exit Code: $($process.ExitCode)")
            
            # MSI exit codes:
            # 0 = Success
            # 1605 = Product not installed
            # 1618 = Another install in progress
            # 1619 = Package could not be opened
            # 3010 = Success, reboot required
            
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                # Verify it's actually gone
                Start-Sleep -Seconds 2
                $stillExists = Test-Path $component.RuntimePath
                if ($stillExists) {
                    $logContent.Add("  [WARN] MSI returned success but folder still exists, attempting folder cleanup...")
                    # MSI uninstall succeeded but left orphaned files - try direct removal
                    try {
                        Remove-Item -Path $component.RuntimePath -Recurse -Force -ErrorAction Stop
                        $logContent.Add("  [OK] Folder removed successfully")
                        $uninstalled.Add($component.DisplayName)
                    } catch {
                        $logContent.Add("  [FAIL] Could not remove folder: $($_.Exception.Message)")
                        $failed.Add("$($component.DisplayName) (folder locked)")
                    }
                } else {
                    if ($process.ExitCode -eq 3010) {
                        $logContent.Add("  [OK] Uninstalled successfully (reboot required)")
                    } else {
                        $logContent.Add("  [OK] Uninstalled successfully")
                    }
                    $uninstalled.Add($component.DisplayName)
                }
            } elseif ($process.ExitCode -eq 1605) {
                $logContent.Add("  [WARN] Product was not installed (already removed?)")
                # Check if folder exists and clean it up
                if (Test-Path $component.RuntimePath) {
                    $logContent.Add("  Folder still exists, attempting cleanup...")
                    try {
                        Remove-Item -Path $component.RuntimePath -Recurse -Force -ErrorAction Stop
                        $logContent.Add("  [OK] Folder removed successfully")
                        $uninstalled.Add($component.DisplayName)
                    } catch {
                        $logContent.Add("  [FAIL] Could not remove folder: $($_.Exception.Message)")
                        $failed.Add("$($component.DisplayName) (folder locked)")
                    }
                } else {
                    $skipped.Add("$($component.DisplayName) (already removed)")
                }
            } else {
                $logContent.Add("  [FAIL] Uninstall failed - check log: $msiLogFile")
                $failed.Add("$($component.DisplayName) (exit: $($process.ExitCode))")
            }
        } else {
            # Unknown uninstall format - log what we found
            $logContent.Add("  [SKIP] Could not parse uninstall command format")
            $skipped.Add("$($component.DisplayName) (unknown format)")
        }
    } catch {
        $logContent.Add("  [FAIL] Error during uninstall: $($_.Exception.Message)")
        $failed.Add("$($component.DisplayName) (error: $($_.Exception.Message))")
    }
    
    $logContent.Add("")
}

# =============================================================================
# SUMMARY
# =============================================================================
$logContent.Add($divider)
$logContent.Add("")
$logContent.Add("%% SUMMARY %%")
$logContent.Add("")

if ($uninstalled.Count -gt 0) {
    $logContent.Add("[UNINSTALLED] $($uninstalled.Count) component(s)")
    foreach ($item in $uninstalled) {
        $logContent.Add("  * $item")
    }
    $logContent.Add("")
}

if ($skipped.Count -gt 0) {
    $logContent.Add("[SKIPPED] $($skipped.Count) component(s)")
    foreach ($item in $skipped) {
        $logContent.Add("  * $item")
    }
    $logContent.Add("")
}

if ($failed.Count -gt 0) {
    $logContent.Add("[FAILED] $($failed.Count) component(s)")
    foreach ($item in $failed) {
        $logContent.Add("  * $item")
    }
    $logContent.Add("")
}

$logContent.Add($divider)

# Determine exit code
if ($failed.Count -gt 0) {
    $logContent.Add("Result: PARTIAL FAILURE")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 1
} elseif ($uninstalled.Count -gt 0) {
    $logContent.Add("Result: SUCCESS")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 0
} else {
    $logContent.Add("Result: NO ACTION TAKEN")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText



    #####            THIS IS JUST FOR TESTING                #####
##### THIS SENDS A MESSAGE TO VINCENT'S PUSHOVER ACCOUNT #####

$logContent.Add("Trying Vincent's Pushover Notification")

# Device and user identification
$deviceName = $env:COMPUTERNAME
$primaryUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
$primaryUser = $primaryUser -replace '.*\\', ''  # Removes "DOMAIN\" prefix
if (-not $primaryUser) {
    # Fallback if no one is logged on
    $primaryUser = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnUser" -ErrorAction SilentlyContinue).LastLoggedOnUser
}
if (-not $primaryUser) {
    $primaryUser = "No user logged on"
}
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name) -replace '^(Detect-|Remediate-)', ''

# Define your Pushover credentials and message details
$apiToken = ""
$userKey = ""
$messageBody = "Script Ran on $deviceName ($primaryUser)"
$messageTitle = "Alert from $scriptName"

# Define the API endpoint URL
$url = "https://api.pushover.net/1/messages.json"

# Create the body for the POST request
$body = @{
    token   = $apiToken
    user    = $userKey
    message = $messageBody
    title   = $messageTitle
}

# Send the request
try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $body
    if ($response.status -eq 1) {
        $logContent.Add("Pushover message sent successfully!")
    } else {
        $logContent.Add("Failed to send Pushover message. Response: $($response.errors)")
    }
} catch {
    $logContent.Add("An error occurred: $_")
}
##################################################################
    exit 0
}

