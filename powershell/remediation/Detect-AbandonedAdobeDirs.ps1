# Detection Script  Detect-AbandonedAdobeDirs.ps1
# Returns exit code 1 if abandoned directories found (triggers remediation)
# Returns exit code 0 if no abandoned directories found (compliant)
# Logs results to c:\r3-it\AdobeDetection.log

$logDir = "C:\R3-IT"
$logFile = "$logDir\AdobeDetection.log"

# Current expected version
$targetVersion = "25.001.20997"
$oldPSChildName = "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"

# Specific directory names to check
$adobeDirNames = @("Acrobat", "Acrobat DC", "Reader", "Reader DC")

# Pre-compile regex pattern for nested directory detection
$adobeDirPattern = "\\($($adobeDirNames -join '|'))(\\|$)"

# Threshold for showing installer details
$lowFileThreshold = 30

# Executables to check for version info (use HashSet for O(1) lookups)
$versionExes = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("Acrobat.exe", "AcroRd32.exe", "AcroRd64.exe", "AcroCEF.exe", "RdrCEF.exe", "RdrServicesUpdater.exe"),
    [StringComparer]::OrdinalIgnoreCase
)

# Track all found exe versions (use Generic List for efficient Add operations)
$foundVersions = [System.Collections.Generic.List[hashtable]]::new()

# Track exe paths we've already reported (HashSet for O(1) contains checks)
$reportedExes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

$divider = "-----------------------------------------------"

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Use Generic List for log content (avoids O(n) array reallocation on each +=)
$logContent = [System.Collections.Generic.List[string]]::new(100)  # Pre-size for expected entries

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logContent.Add("Adobe Abandoned Directory Detection Log")
$logContent.Add("Run Time: $timestamp")
$logContent.Add("Computer: $env:COMPUTERNAME")
$logContent.Add($divider)

$logContent.Add("Expected version: $targetVersion")
$logContent.Add($divider)

# Check registry for installed versions
$logContent.Add("")
$logContent.Add("Registry entries:")

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$registryResults = foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Adobe Acrobat*" -or $_.DisplayName -like "*Adobe Reader*" } |
            Select-Object DisplayName, DisplayVersion, InstallLocation, PSChildName
    }
}

if ($registryResults) {
    foreach ($entry in $registryResults) {
        $logContent.Add("  $($entry.DisplayName) - $($entry.DisplayVersion)")
        if ($entry.InstallLocation) {
            $logContent.Add("    Location: $($entry.InstallLocation)")
        }
    }
            if ($entry.PSChildName) {
            $logContent.Add(" PSChildName: $($entry.PSChildName)")
        }
} else {
    $logContent.Add("  No Adobe Acrobat/Reader entries found")
}

$logContent.Add("")
$logContent.Add($divider)
$logContent.Add("Looking for empty directories named: $($adobeDirNames -join ', ')")
$logContent.Add("(searching recursively)")
$logContent.Add($divider)

$adobeFolders = @(
    "C:\Program Files\Adobe",
    #"C:\Program Files\Common Files\Adobe",
    "C:\Program Files (x86)\Adobe"
    #"C:\Program Files (x86)\Common Files\Adobe"
)

# Collect results into categories (use Generic Lists)
$notFoundFolders = [System.Collections.Generic.List[string]]::new()
$emptyFolders = [System.Collections.Generic.List[string]]::new()
$foldersWithContent = [System.Collections.Generic.List[hashtable]]::new()
$abandonedDirs = [System.Collections.Generic.List[string]]::new()
$remediationHeader = [System.Collections.Generic.List[string]]::new()
$remediationNotes = [System.Collections.Generic.List[string]]::new()

# Track directories we've already processed (to avoid duplicates from overlapping adobeFolders)
$processedDirs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($folder in $adobeFolders) {
    if (-not (Test-Path $folder)) {
        $notFoundFolders.Add($folder)
        continue
    }
    
    # Skip if this folder was already processed as part of a parent scan
    if ($processedDirs.Contains($folder)) {
        continue
    }
    
    # Check if root folder itself is completely empty (no files or subdirs)
    $rootContents = @(Get-ChildItem -Path $folder -Force -ErrorAction SilentlyContinue)
    if ($rootContents.Count -eq 0) {
        $emptyFolders.Add($folder)
        $abandonedDirs.Add($folder)
        [void]$processedDirs.Add($folder)
        continue
    }
    
    # Find all directories matching our names recursively
    $matchingDirs = Get-ChildItem -Path $folder -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in $adobeDirNames }
    
    if (-not $matchingDirs) {
        $emptyFolders.Add($folder)
        continue
    }
    
    $emptyEntries = [System.Collections.Generic.List[string]]::new()
    $contentEntries = [System.Collections.Generic.List[hashtable]]::new()
    
    foreach ($dir in $matchingDirs) {
        $targetPath = $dir.FullName
        
        # Skip if already processed
        if ($processedDirs.Contains($targetPath)) {
            continue
        }
        [void]$processedDirs.Add($targetPath)
        $allItems = @(Get-ChildItem -Path $targetPath -Recurse -File -ErrorAction SilentlyContinue)
        $fileCount = $allItems.Count
        
        if ($fileCount -eq 0) {
            $emptyEntries.Add($targetPath)
            $abandonedDirs.Add($targetPath)
        } else {
            $entry = @{
                Path = $targetPath
                FileCount = $fileCount
                Installers = [System.Collections.Generic.List[hashtable]]::new()
                ExeVersions = [System.Collections.Generic.List[hashtable]]::new()
            }
            
            # Check for Acrobat/Reader executables and get version
            foreach ($file in $allItems) {
                if ($versionExes.Contains($file.Name) -and -not $reportedExes.Contains($file.FullName)) {
                    # Check if this exe is in a subdirectory that matches abandonedNames
                    $exeRelativePath = $file.DirectoryName.Substring($targetPath.Length)
                    
                    if ($exeRelativePath -notmatch $adobeDirPattern) {
                        # Only mark as reported after confirming it's in a valid location
                        [void]$reportedExes.Add($file.FullName)
                        $version = $file.VersionInfo.ProductVersion
                        $entry.ExeVersions.Add(@{
                            Version = $version
                            Path = $file.FullName
                        })
                        $foundVersions.Add(@{
                            Version = $version
                            Path = $file.FullName
                        })
                    }
                }
            }
            
            # Only show installer details if low file count
            if ($fileCount -le $lowFileThreshold) {
                foreach ($file in $allItems) {
                    if ($file.Extension -in @(".exe", ".msi", ".msp") -and -not $reportedExes.Contains($file.FullName)) {
                        $version = $file.VersionInfo.ProductVersion
                        $entry.Installers.Add(@{
                            Version = $version
                            Path = $file.FullName
                        })
                        # Add to foundVersions for summary (only if version exists)
                        if ($version) {
                            $foundVersions.Add(@{
                                Version = $version
                                Path = $file.FullName
                            })
                        }
                    }
                }
            }
            $contentEntries.Add($entry)
        }
    }
    
    if ($emptyEntries.Count -gt 0 -or $contentEntries.Count -gt 0) {
        $foldersWithContent.Add(@{
            Path = $folder
            Empty = $emptyEntries
            Content = $contentEntries
        })
    }
}

# Output: Not Found Folders
if ($notFoundFolders.Count -gt 0) {
    $logContent.Add("")
    $logContent.Add("Root Adobe directories not found:")
    foreach ($folder in $notFoundFolders) {
        $logContent.Add("[NOT FOUND] $folder")
    }
}

# Output: Empty Folders (exist but no matching subdirs)
if ($emptyFolders.Count -gt 0) {
    $logContent.Add("")
    $logContent.Add("%% Root Adobe directories with no Acrobat/Reader subdirs %%")
    foreach ($folder in $emptyFolders) {
        $logContent.Add("[FOUND] $folder")
        $logContent.Add("  No matching directories found")
    }
}

# Output: Folders with content
if ($foldersWithContent.Count -gt 0) {
    $logContent.Add("")
    $logContent.Add("%% Root Adobe directories with Acrobat/Reader subdirs %%")
    foreach ($folder in $foldersWithContent) {
        $logContent.Add("")
        $logContent.Add("[FOUND] $($folder.Path)")
        
        # Build combined list for sorting
        $allEntries = [System.Collections.Generic.List[hashtable]]::new()
        
        foreach ($path in $folder.Empty) {
            $allEntries.Add(@{
                Type = "EMPTY"
                Path = $path
                FileCount = 0
                ExeVersions = @()
                Installers = @()
            })
        }
        
        foreach ($entry in $folder.Content) {
            $allEntries.Add(@{
                Type = "FILES"
                Path = $entry.Path
                FileCount = $entry.FileCount
                ExeVersions = $entry.ExeVersions
                Installers = $entry.Installers
            })
        }
        
        # Sort by path
        $sortedEntries = $allEntries | Sort-Object { $_.Path }
        
        foreach ($entry in $sortedEntries) {
            if ($entry.Type -eq "EMPTY") {
                $logContent.Add("`n[EMPTY] $($entry.Path)")
            } else {
                $logContent.Add(" [FILES] $($entry.Path) ($($entry.FileCount) files)")
                foreach ($exeInfo in $entry.ExeVersions) {
                    $logContent.Add("  [v$($exeInfo.Version)] $($exeInfo.Path)")
                }
                foreach ($installer in $entry.Installers) {
                    if ($installer.Version) {
                        $logContent.Add("  [SETUP] [v$($installer.Version)] $($installer.Path)")
                    } else {
                        $logContent.Add("  [SETUP] $($installer.Path)")
                    }
                }
            }
        }
    }
}

$logContent.Add("")
$logContent.Add($divider)

# Version Summary
$logContent.Add("")
$logContent.Add("%% VERSION SUMMARY %%")
$logContent.Add($timestamp)
$logContent.Add("")
$logContent.Add("[TARGET] v$targetVersion")

if ($foundVersions.Count -gt 0) {
    # Normalize versions for comparison
    $normalizedVersions = [System.Collections.Generic.List[hashtable]]::new($foundVersions.Count)
    foreach ($item in $foundVersions) {
        # Convert version like 25.1.20997.0 to 25.001.20997 for comparison
        $parts = $item.Version -split '\.'
        if ($parts.Count -ge 3) {
            $normalized = "{0}.{1:D3}.{2}" -f [int]$parts[0], [int]$parts[1], $parts[2]
        } else {
            $normalized = $item.Version
        }
        $normalizedVersions.Add(@{
            Original = $item.Version
            Normalized = $normalized
            Path = $item.Path
        })
    }
    
    # Get unique versions sorted descending
    $uniqueVersions = @($normalizedVersions | ForEach-Object { $_.Normalized } | Select-Object -Unique | Sort-Object -Descending)
    
    if ($uniqueVersions.Count -gt 0) {
        $newestVersion = $uniqueVersions[0]
        
        # Latest versions
        $logContent.Add("")
        $isTarget = if ($newestVersion -eq $targetVersion) { "(Yay!)" } else { "(boo!)" }
        $logContent.Add("[LATEST] $newestVersion - $isTarget")
        $latestPaths = $normalizedVersions | Where-Object { $_.Normalized -eq $newestVersion }
        foreach ($item in $latestPaths) {
            $logContent.Add("[L] $($item.Path)")
        }
        
        # Registry comparison
        $logContent.Add("")
        $logContent.Add("[REGISTRY]")
        if ($registryResults) {
            foreach ($regEntry in $registryResults) {
                $regVersion = $regEntry.DisplayVersion
                $regLocation = $regEntry.InstallLocation
                
                # Normalize registry version for comparison
                $regParts = $regVersion -split '\.'
                if ($regParts.Count -ge 3) {
                    $regNormalized = "{0}.{1:D3}.{2}" -f [int]$regParts[0], [int]$regParts[1], $regParts[2]
                } else {
                    $regNormalized = $regVersion
                }
                
                # Check if registry version matches latest
                $versionMatch = if ($regNormalized -eq $newestVersion) { "YES" } else { "NO" }

                # Check if PSChildName matches deprecated version
                $PSChildNameMatch = if ($PSChildName -eq $oldPSChildName) { "YES" } else { "NO" }
                
                # Check if any latest exe paths start with the registry install location
                $pathMatch = "NO"
                if ($regLocation) {
                    $regLocationNorm = $regLocation.TrimEnd('\')
                    foreach ($latestItem in $latestPaths) {
                        if ($latestItem.Path -like "$regLocationNorm\*") {
                            $pathMatch = "YES"
                            break
                        }
                    }
                } else {
                    $pathMatch = "N/A (no install path)"
                }
                
                $logContent.Add("[REGISTRY] $regNormalized")
                $logContent.Add("[R] $(if ($regLocation) { $regLocation } else { '(not specified)' })")
                #$logContent.Add("    Version: $regVersion (normalized: $regNormalized)")
                $logContent.Add("Version matches latest: $versionMatch")
                $logContent.Add("Install path matches  : $pathMatch")
                $logContent.Add("PSChildName matches   : $PSChildNameMatch")
            }
        } else {
            $logContent.Add("    No Adobe registry entries found")
        }
        
        # Outdated versions (if different from latest)
        $outdatedPaths = @($normalizedVersions | Where-Object { $_.Normalized -ne $newestVersion } | Sort-Object { $_.Normalized } -Descending)
        if ($outdatedPaths.Count -gt 0) {
            $numOldVers = 0
            $pathsOldVers = ""
            
            # Group by version
            $groupedByVersion = $outdatedPaths | Group-Object { $_.Normalized }
            
            foreach ($group in $groupedByVersion) {
                $logContent.Add("")
                $logContent.Add("[OUTDATED] $($group.Name)")
                foreach ($item in $group.Group) {
                    $numOldVers++
                    $pathsOldVers += "`n[$($item.Normalized)] $($item.Path)"
                    $logContent.Add("[O] $($item.Path)")
                }
            }
            $remediationHeader.Add("Old Vs: $numOldVers")
            $remediationNotes.Add("`n[Old Vs] $pathsOldVers`n")
        }
    }
} else {
    $logContent.Add("  No Adobe executables found")
}

$logContent.Add("")
$logContent.Add($divider)

# Convert lists to strings for output
$remediationHeaderStr = $remediationHeader -join ", "
#$remediationNotesStr = $remediationNotes -join ""

if ($abandonedDirs.Count -gt 0) {
    $numOldDirs = 0
    $pathsOldDir = ""
    $logContent.Add("%% Abandoned directories to remediate %%")
    foreach ($dir in $abandonedDirs) {
        $numOldDirs++
        $pathsOldDir += "`n$dir"
        $logContent.Add("$dir")
    }
    $remediationHeader.Add("Old Dirs: $numOldDirs")
    $remediationNotes.Add("`n[Old Dirs] $pathsOldDir`n")
    
    # Rebuild strings after adding
    $remediationHeaderStr = $remediationHeader -join ", "
   # $remediationNotesStr = $remediationNotes -join ""

    $logContent.Add("")
    $logContent.Add($divider)
    # $logContent.Add("Result: NON-COMPLIANT [$remediationHeaderStr]`n$remediationNotesStr")
    $logContent.Add("Result: NON-COMPLIANT [$remediationHeaderStr]")
    
    # Write log (join once for output)
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    # Output for Intune
    Write-Host $outputText
    exit 1
} else {
    $logContent.Add("No abandoned directories found.")
    $logContent.Add("")
    $logContent.Add($divider)
    $logContent.Add("Result: COMPLIANT")
    
    # Write log (join once for output)
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    
    # Output for Intune
    Write-Host $outputText
    exit 0
}