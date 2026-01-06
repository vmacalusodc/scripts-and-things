# Detection Script: Detect-OutdatedDotNet.ps1
# Returns exit code 1 if end-of-life .NET runtimes found (triggers remediation)
# Returns exit code 0 if no EOL runtimes found (compliant)
# Logs results to C:\R3-IT\DotNetDetection.log

$logDir = "C:\R3-IT"
$logFile = "$logDir\DotNetDetection.log"

# Configuration: Skip detailed file enumeration (improves performance, reduces false positives)
$skipFileEnumeration = $false  # Set to $true to skip listing individual files in runtime directories

# .NET Support Policy Reference:
# https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core

# End of Life dates for .NET versions (update as needed)
# Format: Major.Minor = EOL Date
$eolDates = @{
    "3.0" = [datetime]"2020-03-03"
    "3.1" = [datetime]"2022-12-13"
    "5.0" = [datetime]"2022-05-10"
    "6.0" = [datetime]"2024-11-12"
    "7.0" = [datetime]"2024-05-14"
    # Currently supported (LTS until November 2026)
    "8.0" = [datetime]"2026-11-10"
    # Currently supported (STS until May 2026)  
    "9.0" = [datetime]"2026-05-12"
}

# Runtime types to check
$runtimeTypes = @(
    "Microsoft.NETCore.App",
    "Microsoft.AspNetCore.App",
    "Microsoft.WindowsDesktop.App"
)

# Dotnet root paths to check
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

# Use Generic List for log content
$logContent = [System.Collections.Generic.List[string]]::new(100)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logContent.Add(".NET Runtime End-of-Life Detection Log")
$logContent.Add("Run Time: $timestamp")
$logContent.Add("Computer: $env:COMPUTERNAME")
$logContent.Add($divider)

# =============================================================================
# DEVELOPER MACHINE DETECTION (Informational only - does not affect compliance)
# =============================================================================
$logContent.Add("")
$logContent.Add("%% DEVELOPER MACHINE CHECK %%")

$isDeveloperMachine = $false
$devReasons = [System.Collections.Generic.List[string]]::new()

# Check registry for Visual Studio installations
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$vsInstallations = [System.Collections.Generic.List[string]]::new()

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        $vsEntries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.DisplayName -like "Microsoft Visual Studio 20*" -or
                $_.DisplayName -like "Visual Studio Community*" -or
                $_.DisplayName -like "Visual Studio Professional*" -or
                $_.DisplayName -like "Visual Studio Enterprise*"
            } |
            Select-Object DisplayName, DisplayVersion -Unique
        
        foreach ($entry in $vsEntries) {
            if ($entry.DisplayName -and -not ($vsInstallations -contains $entry.DisplayName)) {
                $isDeveloperMachine = $true
                $vsInstallations.Add("$($entry.DisplayName) ($($entry.DisplayVersion))")
            }
        }
    }
}

# Check for VS Code
$vsCodePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "$env:ProgramFiles\Microsoft VS Code\Code.exe",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
)
foreach ($vsCodePath in $vsCodePaths) {
    if (Test-Path $vsCodePath) {
        $isDeveloperMachine = $true
        if (-not ($vsInstallations | Where-Object { $_ -like "*VS Code*" })) {
            $vsInstallations.Add("Visual Studio Code")
        }
        break
    }
}

# Check for JetBrains Rider
$riderPaths = @(
    "$env:LOCALAPPDATA\Programs\Rider\*",
    "$env:ProgramFiles\JetBrains\*Rider*"
)
foreach ($riderPath in $riderPaths) {
    if (Test-Path $riderPath) {
        $isDeveloperMachine = $true
        if (-not ($vsInstallations | Where-Object { $_ -like "*Rider*" })) {
            $vsInstallations.Add("JetBrains Rider")
        }
        break
    }
}

# Check for .NET SDK (strong indicator of development use)
$installedSdks = [System.Collections.Generic.List[string]]::new()
foreach ($dotnetRoot in $dotnetRoots) {
    $sdkPath = Join-Path $dotnetRoot "sdk"
    if (Test-Path $sdkPath) {
        $sdkDirs = Get-ChildItem -Path $sdkPath -Directory -ErrorAction SilentlyContinue
        foreach ($sdk in $sdkDirs) {
            $installedSdks.Add("$($sdk.Name) [$dotnetRoot]")
        }
    }
}
if ($installedSdks.Count -gt 0) {
    $isDeveloperMachine = $true
    $devReasons.Add(".NET SDK installed")
}

# Output developer machine findings
$logContent.Add("")
if ($isDeveloperMachine) {
    $logContent.Add("[!] POSSIBLE DEVELOPER MACHINE DETECTED [!]")
    $logContent.Add("")
    if ($vsInstallations.Count -gt 0) {
        $logContent.Add("  Development tools found:")
        foreach ($vs in $vsInstallations) {
            $logContent.Add("    * $vs")
        }
    }
    if ($installedSdks.Count -gt 0) {
        $logContent.Add("")
        $logContent.Add("  .NET SDKs installed:")
        foreach ($sdk in $installedSdks | Sort-Object) {
            $logContent.Add("    * $sdk")
        }
    }
    $logContent.Add("")
    $logContent.Add("  NOTE: EOL runtimes may be intentionally installed for development.")
    $logContent.Add("        Review before remediation.")
} else {
    $logContent.Add("  No developer tools detected - appears to be end-user machine")
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# REGISTRY: INSTALLED .NET COMPONENTS
# =============================================================================
$logContent.Add("")
$logContent.Add("%% REGISTRY: .NET INSTALLATIONS %%")
$logContent.Add("")

$dotnetRegistryEntries = [System.Collections.Generic.List[hashtable]]::new()

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.DisplayName -like "Microsoft .NET Runtime*" -or
                $_.DisplayName -like "Microsoft ASP.NET Core*" -or
                $_.DisplayName -like "Microsoft Windows Desktop Runtime*" -or
                $_.DisplayName -like "Microsoft .NET SDK*" -or
                $_.DisplayName -like "Microsoft .NET Host*" -or
                $_.DisplayName -like "Microsoft .NET AppHost*"
            } |
            Select-Object DisplayName, DisplayVersion, UninstallString, PSPath
        
        foreach ($entry in $entries) {
            if ($entry.DisplayName) {
                # Extract version from display name (e.g., "Microsoft .NET Runtime - 6.0.36 (x64)" -> "6.0.36")
                $version = ""
                $majorMinor = ""
                $arch = ""
                $componentType = ""
                
                if ($entry.DisplayName -match '(\d+\.\d+\.\d+)') {
                    $version = $matches[1]
                    if ($version -match '^(\d+\.\d+)') {
                        $majorMinor = $matches[1]
                    }
                }
                
                if ($entry.DisplayName -match '\((x64|x86)\)') {
                    $arch = $matches[1]
                }
                
                # Determine component type
                if ($entry.DisplayName -like "*SDK*") {
                    $componentType = "SDK"
                } elseif ($entry.DisplayName -like "*ASP.NET*") {
                    $componentType = "AspNetCore"
                } elseif ($entry.DisplayName -like "*Windows Desktop*") {
                    $componentType = "WindowsDesktop"
                } elseif ($entry.DisplayName -like "*Host*" -or $entry.DisplayName -like "*AppHost*") {
                    $componentType = "Host"
                } else {
                    $componentType = "Runtime"
                }
                
                # Check if EOL
                $isEol = $false
                $eolDate = $null
                if ($majorMinor -and $eolDates.ContainsKey($majorMinor)) {
                    $eolDate = $eolDates[$majorMinor]
                    $isEol = $today -gt $eolDate
                }
                
                $dotnetRegistryEntries.Add(@{
                    DisplayName = $entry.DisplayName
                    Version = $version
                    MajorMinor = $majorMinor
                    Architecture = $arch
                    ComponentType = $componentType
                    UninstallString = $entry.UninstallString
                    IsEol = $isEol
                    EolDate = $eolDate
                })
            }
        }
    }
}

if ($dotnetRegistryEntries.Count -gt 0) {
    # Group by EOL status
    $eolEntries = $dotnetRegistryEntries | Where-Object { $_.IsEol } | Sort-Object { $_.DisplayName }
    $currentEntries = $dotnetRegistryEntries | Where-Object { -not $_.IsEol } | Sort-Object { $_.DisplayName }
    
    if ($currentEntries.Count -gt 0) {
        $logContent.Add("[CURRENT] $($currentEntries.Count) component(s)")
        foreach ($entry in $currentEntries) {
            $logContent.Add("  $($entry.DisplayName)")
        }
    }
    
    if ($eolEntries.Count -gt 0) {
        $logContent.Add("")
        $logContent.Add("[EOL] $($eolEntries.Count) component(s)")
        foreach ($entry in $eolEntries) {
            $eolStr = if ($entry.EolDate) { " (EOL: $($entry.EolDate.ToString('yyyy-MM-dd')))" } else { "" }
            $logContent.Add("  $($entry.DisplayName)$eolStr")
            if ($entry.UninstallString) {
                $logContent.Add("    Uninstall: $($entry.UninstallString)")
            }
        }
    }
} else {
    $logContent.Add("  No .NET components found in registry")
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# CHECK FOR CURRENTLY LOADED .NET RUNTIME DLLS
# =============================================================================
$logContent.Add("")
$logContent.Add("%% RUNTIME DLLs CURRENTLY LOADED %%")
$logContent.Add("")

$loadedRuntimes = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new(
    [StringComparer]::OrdinalIgnoreCase
)

try {
    $processes = Get-Process -ErrorAction SilentlyContinue
    foreach ($proc in $processes) {
        try {
            $modules = $proc.Modules | Where-Object { 
                $_.FileName -like "*\dotnet\shared\*" 
            }
            foreach ($module in $modules) {
                # Extract the runtime path (up to version folder)
                # e.g., C:\Program Files\dotnet\shared\Microsoft.NETCore.App\6.0.36
                if ($module.FileName -match '(.*\\dotnet\\shared\\[^\\]+\\[\d\.]+)\\') {
                    $runtimePath = $matches[1]
                    if (-not $loadedRuntimes.ContainsKey($runtimePath)) {
                        $loadedRuntimes[$runtimePath] = [System.Collections.Generic.List[string]]::new()
                    }
                    $procName = "$($proc.ProcessName) (PID: $($proc.Id))"
                    if (-not $loadedRuntimes[$runtimePath].Contains($procName)) {
                        $loadedRuntimes[$runtimePath].Add($procName)
                    }
                }
            }
        } catch {
            # Access denied to process modules - skip silently
        }
    }
} catch {
    $logContent.Add("  Error enumerating processes: $($_.Exception.Message)")
}

if ($loadedRuntimes.Count -gt 0) {
    $logContent.Add("[!] RUNTIMES CURRENTLY IN USE [!]")
    $logContent.Add("")
    foreach ($runtimePath in $loadedRuntimes.Keys | Sort-Object) {
        $logContent.Add("  $runtimePath")
        foreach ($procName in $loadedRuntimes[$runtimePath] | Sort-Object) {
            $logContent.Add("    - $procName")
        }
        $logContent.Add("")
    }
} else {
    $logContent.Add("  No .NET runtime DLLs currently loaded by running processes")
}

$logContent.Add($divider)

# =============================================================================
# SCAN FOR INSTALLED .NET RUNTIMES
# =============================================================================

# Track findings
$eolRuntimes = [System.Collections.Generic.List[hashtable]]::new()
$supportedRuntimes = [System.Collections.Generic.List[hashtable]]::new()
$unknownRuntimes = [System.Collections.Generic.List[hashtable]]::new()

$logContent.Add("")
$logContent.Add("%% INSTALLED .NET RUNTIMES %%")
$logContent.Add($divider)

foreach ($dotnetRoot in $dotnetRoots) {
    if (-not (Test-Path $dotnetRoot)) {
        $logContent.Add("")
        $logContent.Add("[$dotnetRoot] - Not found")
        continue
    }
    
    $logContent.Add("")
    $logContent.Add("[$dotnetRoot]")
    
    $sharedPath = Join-Path $dotnetRoot "shared"
    
    if (-not (Test-Path $sharedPath)) {
        $logContent.Add("  No shared runtimes directory found")
        continue
    }
    
    foreach ($runtimeType in $runtimeTypes) {
        $runtimeTypePath = Join-Path $sharedPath $runtimeType
        
        if (-not (Test-Path $runtimeTypePath)) {
            continue
        }
        
        $logContent.Add("")
        $logContent.Add("  $runtimeType")
        
        # Get all version directories
        $versionDirs = Get-ChildItem -Path $runtimeTypePath -Directory -ErrorAction SilentlyContinue
        
        foreach ($versionDir in $versionDirs) {
            $fullVersion = $versionDir.Name
            
            # Get folder timestamps (folder metadata only - not affected by enumeration)
            $folderLastAccess = $versionDir.LastAccessTime
            $folderLastWrite = $versionDir.LastWriteTime
            $daysSinceWrite = [math]::Round(($today - $folderLastWrite).TotalDays)
            $daysSinceAccess = [math]::Round(($today - $folderLastAccess).TotalDays)
            
            # Check if this runtime is currently loaded
            $isCurrentlyLoaded = $loadedRuntimes.ContainsKey($versionDir.FullName)
            
            # Extract major.minor from version (e.g., "6.0.36" -> "6.0")
            if ($fullVersion -match '^(\d+\.\d+)') {
                $majorMinor = $matches[1]
            } else {
                # Can't parse version
                $unknownRuntimes.Add(@{
                    Path = $versionDir.FullName
                    Version = $fullVersion
                    RuntimeType = $runtimeType
                    Architecture = if ($dotnetRoot -like "*x86*") { "x86" } else { "x64" }
                    LastAccessTime = $folderLastAccess
                    LastWriteTime = $folderLastWrite
                    DaysSinceAccess = $daysSinceAccess
                    DaysSinceWrite = $daysSinceWrite
                    IsLoaded = $isCurrentlyLoaded
                })
                $logContent.Add("    [?] $fullVersion - Unknown version format")
                continue
            }
            
            # Check EOL status
            if ($eolDates.ContainsKey($majorMinor)) {
                $eolDate = $eolDates[$majorMinor]
                $isEol = $today -gt $eolDate
                
                $runtimeInfo = @{
                    Path = $versionDir.FullName
                    Version = $fullVersion
                    MajorMinor = $majorMinor
                    RuntimeType = $runtimeType
                    Architecture = if ($dotnetRoot -like "*x86*") { "x86" } else { "x64" }
                    EolDate = $eolDate
                    IsEol = $isEol
                    LastAccessTime = $folderLastAccess
                    LastWriteTime = $folderLastWrite
                    DaysSinceAccess = $daysSinceAccess
                    DaysSinceWrite = $daysSinceWrite
                    IsLoaded = $isCurrentlyLoaded
                }
                
                if ($isEol) {
                    $eolRuntimes.Add($runtimeInfo)
                    $daysPastEol = [math]::Round(($today - $eolDate).TotalDays)
                    
                    # Build status indicators (using LastWriteTime for "recent" determination)
                    $loadedIndicator = if ($isCurrentlyLoaded) { " [LOADED]" } else { "" }
                    $writeIndicator = if ($daysSinceWrite -le 30) { " [RECENT]" } else { "" }
                    
                    $logContent.Add("    [EOL] $fullVersion - End of Life: $($eolDate.ToString('yyyy-MM-dd')) ($daysPastEol days ago)$loadedIndicator$writeIndicator")
                    $logContent.Add("          Folder last write: $($folderLastWrite.ToString('yyyy-MM-dd HH:mm')) ($daysSinceWrite days ago)")
                    $logContent.Add("          Folder last access: $($folderLastAccess.ToString('yyyy-MM-dd HH:mm')) ($daysSinceAccess days ago)")
                } else {
                    $supportedRuntimes.Add($runtimeInfo)
                    $daysRemaining = [math]::Round(($eolDate - $today).TotalDays)
                    $logContent.Add("    [OK] $fullVersion - Support until: $($eolDate.ToString('yyyy-MM-dd')) ($daysRemaining days)")
                }
            } else {
                # Version not in our EOL table
                $unknownRuntimes.Add(@{
                    Path = $versionDir.FullName
                    Version = $fullVersion
                    MajorMinor = $majorMinor
                    RuntimeType = $runtimeType
                    Architecture = if ($dotnetRoot -like "*x86*") { "x86" } else { "x64" }
                    LastAccessTime = $folderLastAccess
                    LastWriteTime = $folderLastWrite
                    DaysSinceAccess = $daysSinceAccess
                    DaysSinceWrite = $daysSinceWrite
                    IsLoaded = $isCurrentlyLoaded
                })
                $logContent.Add("    [?] $fullVersion - EOL date not in database")
            }
        }
    }
}

# Check dotnet --list-runtimes output for comparison
$logContent.Add("")
$logContent.Add($divider)
$logContent.Add("dotnet --list-runtimes output:")

try {
    $dotnetExe = "C:\Program Files\dotnet\dotnet.exe"
    if (Test-Path $dotnetExe) {
        $runtimeList = & $dotnetExe --list-runtimes 2>&1
        foreach ($line in $runtimeList) {
            $logContent.Add("  $line")
        }
    } else {
        $logContent.Add("  dotnet.exe not found at default location")
    }
} catch {
    $logContent.Add("  Error running dotnet --list-runtimes: $($_.Exception.Message)")
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

# Developer machine warning
if ($isDeveloperMachine) {
    $logContent.Add("[!] DEVELOPER MACHINE - Review before remediation")
    $logContent.Add("")
}

# Supported runtimes
$logContent.Add("[SUPPORTED] $($supportedRuntimes.Count) runtime(s)")
if ($supportedRuntimes.Count -gt 0) {
    foreach ($rt in $supportedRuntimes | Sort-Object { $_.Version } -Descending) {
        $logContent.Add("  $($rt.RuntimeType) $($rt.Version) [$($rt.Architecture)]")
    }
}

# Unknown runtimes
if ($unknownRuntimes.Count -gt 0) {
    $logContent.Add("")
    $logContent.Add("[UNKNOWN] $($unknownRuntimes.Count) runtime(s) - EOL date not in database")
    foreach ($rt in $unknownRuntimes | Sort-Object { $_.Version } -Descending) {
        $logContent.Add("  $($rt.RuntimeType) $($rt.Version) [$($rt.Architecture)]")
    }
}

# EOL runtimes with usage info
if ($eolRuntimes.Count -gt 0) {
    $logContent.Add("")
    $logContent.Add("[END OF LIFE] $($eolRuntimes.Count) runtime(s)")
    
    # Separate into loaded/recent vs inactive (using LastWriteTime to avoid false positives)
    $activeEol = $eolRuntimes | Where-Object { $_.IsLoaded -or $_.DaysSinceWrite -le 30 }
    $inactiveEol = $eolRuntimes | Where-Object { -not $_.IsLoaded -and $_.DaysSinceWrite -gt 30 }
    
    if ($activeEol.Count -gt 0) {
        $logContent.Add("")
        $logContent.Add("  ** POTENTIALLY IN USE ** ($($activeEol.Count) runtime(s))")
        foreach ($rt in $activeEol | Sort-Object { $_.Path }) {
            $loadedTag = if ($rt.IsLoaded) { "[LOADED NOW] " } else { "" }
            $logContent.Add("    $loadedTag$($rt.Path)")
            $logContent.Add("      .NET $($rt.MajorMinor) - EOL: $($rt.EolDate.ToString('yyyy-MM-dd'))")
            $logContent.Add("      Folder last write: $($rt.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) ($($rt.DaysSinceWrite) days ago)")
            $logContent.Add("      Folder last access: $($rt.LastAccessTime.ToString('yyyy-MM-dd HH:mm')) ($($rt.DaysSinceAccess) days ago)")
            if ($rt.IsLoaded) {
                $logContent.Add("      Processes: $($loadedRuntimes[$rt.Path] -join ', ')")
            }
            
            # Show recently modified files in this runtime directory (only if not skipping enumeration)
            if (-not $skipFileEnumeration) {
                $logContent.Add("      Recently modified files (last 30 days):")
                try {
                    $recentFiles = Get-ChildItem -Path $rt.Path -Recurse -File -ErrorAction SilentlyContinue |
                        Where-Object { ($today - $_.LastWriteTime).TotalDays -le 30 } |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 15
                    
                    if ($recentFiles) {
                        foreach ($file in $recentFiles) {
                            $fileAge = [math]::Round(($today - $file.LastWriteTime).TotalDays)
                            $relativePath = $file.FullName.Substring($rt.Path.Length + 1)
                            $logContent.Add("        [$fileAge d] $relativePath")
                        }
                        $totalRecent = (Get-ChildItem -Path $rt.Path -Recurse -File -ErrorAction SilentlyContinue |
                            Where-Object { ($today - $_.LastWriteTime).TotalDays -le 30 }).Count
                        if ($totalRecent -gt 15) {
                            $logContent.Add("        ... and $($totalRecent - 15) more files")
                        }
                    } else {
                        $logContent.Add("        (no files modified in last 30 days)")
                    }
                } catch {
                    $logContent.Add("        (error reading directory)")
                }
            } else {
                $logContent.Add("      [File enumeration skipped - see \$skipFileEnumeration setting]")
            }
        }
    }
    
    if ($inactiveEol.Count -gt 0) {
        $logContent.Add("")
        $logContent.Add("  ** LIKELY SAFE TO REMOVE ** ($($inactiveEol.Count) runtime(s))")
        $logContent.Add("  (Not loaded, last write > 30 days ago)")
        foreach ($rt in $inactiveEol | Sort-Object { $_.Path }) {
            $logContent.Add("    $($rt.Path)")
            $logContent.Add("      .NET $($rt.MajorMinor) - EOL: $($rt.EolDate.ToString('yyyy-MM-dd'))")
            $logContent.Add("      Folder last write: $($rt.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) ($($rt.DaysSinceWrite) days ago)")
            $logContent.Add("      Folder last access: $($rt.LastAccessTime.ToString('yyyy-MM-dd HH:mm')) ($($rt.DaysSinceAccess) days ago)")
        }
    }
}

$logContent.Add("")
$logContent.Add($divider)

# =============================================================================
# COMPLIANCE RESULT
# =============================================================================
if ($eolRuntimes.Count -gt 0) {
    $logContent.Add("")
    $logContent.Add("%% Paths to remediate %%")
    foreach ($rt in $eolRuntimes | Sort-Object { $_.Path }) {
        $flags = @()
        if ($rt.IsLoaded) { $flags += "LOADED" }
        if ($rt.DaysSinceWrite -le 30) { $flags += "RECENT" }
        if ($isDeveloperMachine) { $flags += "DEV-MACHINE" }
        
        $flagStr = if ($flags.Count -gt 0) { " [" + ($flags -join ", ") + "]" } else { "" }
        $logContent.Add("$($rt.Path)$flagStr")
    }
    
    $logContent.Add("")
    $logContent.Add($divider)
    
    $activeCount = ($eolRuntimes | Where-Object { $_.IsLoaded -or $_.DaysSinceWrite -le 30 }).Count
    $summaryNote = ""
    if ($activeCount -gt 0) {
        $summaryNote = " ($activeCount potentially in use - review before remediation)"
    }
    if ($isDeveloperMachine) {
        $summaryNote = " (DEVELOPER MACHINE - review before remediation)"
    }
    
    $logContent.Add("Result: NON-COMPLIANT [EOL Runtimes: $($eolRuntimes.Count)]$summaryNote")
    
    # Write log
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    # Output for Intune
    Write-Host $outputText
    exit 1
} else {
    $logContent.Add("No end-of-life .NET runtimes found.")
    $logContent.Add("")
    $logContent.Add($divider)
    $logContent.Add("Result: COMPLIANT")
    
    # Write log
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    # Output for Intune
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
