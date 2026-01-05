# Remediation Script - Remediate-AbandonedAdobeDirs.ps1
# Reads detection log for outdated files and abandoned directories, removes them safely
# Logs results to c:\r3-it\AdobeRemediation.log

# ============================================
# GROUP-BASED REMEDIATION LEVEL CONFIGURATION
# ============================================
# The script will automatically detect which Intune group triggered this execution
# and set the remediation level accordingly.

# Define your Intune group names and their corresponding remediation levels
$groupLevelMap = @{
    "RemediationGroup1" = 1  # Conservative - abandoned directories only
    "RemediationGroup2" = 2  # Standard - abandoned + outdated with validation
    "RemediationGroup3" = 3  # Aggressive - force removal without validation
}

# Default level if group cannot be determined (safety first)
$defaultLevel = 0

# Manual override (for testing outside of Intune)
$manualMode = $false
$manualLevel = 0

# ============================================
# DETECT WHICH INTUNE GROUP TRIGGERED THIS SCRIPT
# ============================================
$remediationLevel = $defaultLevel
$detectedGroup = $null
$detectionMethod = "Default (no group detected)"

if (-not $manualMode) {
    try {
        # Method 1: Check Intune Management Extension registry for current execution context
        # When Intune runs a remediation script, it stores execution metadata in registry
        $intuneRegBase = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension"
        
        # Get the current user context (device vs user assignment)
       # $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        
        # Check for device-targeted policies (most common for remediation scripts)
        $devicePoliciesPath = "$intuneRegBase\Policies"
        if (Test-Path $devicePoliciesPath) {
            # Look for recent policy executions
            $policyKeys = Get-ChildItem -Path $devicePoliciesPath -ErrorAction SilentlyContinue
            
            foreach ($policyKey in $policyKeys) {
                try {
                    $policyProps = Get-ItemProperty -Path $policyKey.PSPath -ErrorAction SilentlyContinue
                    
                    # Check if this is our remediation script by looking at result data
                    if ($policyProps) {
                        # Intune stores the assignment group information in the policy data
                        # The group name or ID may be in various properties
                        
                        foreach ($groupName in $groupLevelMap.Keys) {
                            # Check if any property contains our group name
                            $matchFound = $false
                            foreach ($prop in $policyProps.PSObject.Properties) {
                                if ($prop.Value -like "*$groupName*") {
                                    $detectedGroup = $groupName
                                    $remediationLevel = $groupLevelMap[$groupName]
                                    $detectionMethod = "Intune Policy Registry"
                                    $matchFound = $true
                                    break
                                }
                            }
                            if ($matchFound) { break }
                        }
                    }
                } catch {
                    # Continue checking other keys
                }
                
                if ($detectedGroup) { break }
            }
        }
        
        # Method 2: Check SideCar policies (remediation scripts specific path)
        if (-not $detectedGroup) {
            $sideCarPath = "$intuneRegBase\SideCarPolicies\Scripts\Reports"
            if (Test-Path $sideCarPath) {
                $scriptKeys = Get-ChildItem -Path $sideCarPath -Recurse -ErrorAction SilentlyContinue
                
                foreach ($scriptKey in $scriptKeys) {
                    try {
                        $scriptProps = Get-ItemProperty -Path $scriptKey.PSPath -ErrorAction SilentlyContinue
                        
                        if ($scriptProps) {
                            foreach ($groupName in $groupLevelMap.Keys) {
                                foreach ($prop in $scriptProps.PSObject.Properties) {
                                    if ($prop.Value -like "*$groupName*") {
                                        $detectedGroup = $groupName
                                        $remediationLevel = $groupLevelMap[$groupName]
                                        $detectionMethod = "Intune SideCar Registry"
                                        break
                                    }
                                }
                                if ($detectedGroup) { break }
                            }
                        }
                    } catch {
                        # Continue
                    }
                    
                    if ($detectedGroup) { break }
                }
            }
        }
        
        # Method 3: Parse IME logs for group assignment (most reliable)
        if (-not $detectedGroup) {
            $imeLogsPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
            $imeLog = "$imeLogsPath\IntuneManagementExtension.log"
            
            if (Test-Path $imeLog) {
                # Read last 5000 lines of log (recent executions)
                $logLines = Get-Content -Path $imeLog -Tail 5000 -ErrorAction SilentlyContinue
                
                # Look for remediation script execution with group assignment
                foreach ($line in $logLines) {
                    foreach ($groupName in $groupLevelMap.Keys) {
                        if ($line -match $groupName -and $line -match "HealthScript|Remediation") {
                            $detectedGroup = $groupName
                            $remediationLevel = $groupLevelMap[$groupName]
                            $detectionMethod = "IME Log Analysis"
                            break
                        }
                    }
                    if ($detectedGroup) { break }
                }
            }
        }
        
        # Method 4: Check environment variables set by Intune
        if (-not $detectedGroup) {
            foreach ($groupName in $groupLevelMap.Keys) {
                # Check various environment variables Intune might set
                $envVars = @($env:INTUNE_TARGETGROUPNAME, $env:INTUNE_ASSIGNMENTGROUP)
                
                foreach ($envVar in $envVars) {
                    if ($envVar -like "*$groupName*") {
                        $detectedGroup = $groupName
                        $remediationLevel = $groupLevelMap[$groupName]
                        $detectionMethod = "Environment Variable"
                        break
                    }
                }
                
                if ($detectedGroup) { break }
            }
        }
        
        # Method 5: Check command line arguments (if passed by wrapper script)
        if (-not $detectedGroup) {
            $scriptArgs = $MyInvocation.Line
            foreach ($groupName in $groupLevelMap.Keys) {
                if ($scriptArgs -like "*$groupName*") {
                    $detectedGroup = $groupName
                    $remediationLevel = $groupLevelMap[$groupName]
                    $detectionMethod = "Command Line Argument"
                    break
                }
            }
        }
        
    } catch {
        # If any error in detection, fall back to default
        $detectionMethod = "Error in detection (using default): $($_.Exception.Message)"
    }
} else {
    # Manual mode for testing
    $remediationLevel = $manualLevel
    $detectionMethod = "Manual Override"
}

$logDir = "C:\R3-IT"
$detectionLog = "$logDir\AdobeDetection.log"
$logFile = "$logDir\AdobeRemediation.log"

$rootAdobeFolders = @(
    "C:\Program Files\Adobe",
    "C:\Program Files\Common Files\Adobe",
    "C:\Program Files (x86)\Adobe",
    "C:\Program Files (x86)\Common Files\Adobe"
)

# Use Generic Lists for efficiency
$logContent = [System.Collections.Generic.List[string]]::new(100)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logContent.Add("Adobe Abandoned Directory Remediation Log")
$logContent.Add("Run Time: $timestamp")
$logContent.Add("Computer: $env:COMPUTERNAME")
$logContent.Add("User: $env:USERNAME")
$logContent.Add("Remediation Level: $remediationLevel")
$logContent.Add("Detection Method: $detectionMethod")
if ($detectedGroup) {
    $logContent.Add("Detected Group: $detectedGroup")
}
switch ($remediationLevel) {
    0 { $logContent.Add("  [Level 0] TEST MODE - No changes will be made") }
    1 { $logContent.Add("  [Level 1] Remove empty/abandoned directories only") }
    2 { $logContent.Add("  [Level 2] Remove abandoned directories + outdated files (with validation)") }
    3 { $logContent.Add("  [Level 3] AGGRESSIVE - Remove outdated files without validation") }
}
$logContent.Add("----------------------------------------")

# Check if detection log exists
if (-not (Test-Path $detectionLog)) {
    $logContent.Add("ERROR: Detection log not found at $detectionLog")
    $logContent.Add("Run detection script first.")
    $outputText = $logContent -join "`n"
    $outputText | Out-File -FilePath $logFile -Force -Encoding UTF8
    Write-Host $outputText
    exit 1
}

$logContent.Add("Reading from: $detectionLog")
$logContent.Add("----------------------------------------")

# Parse detection log
$detectionContent = Get-Content $detectionLog

# Extract Latest entries [L]
$latestEntries = [System.Collections.Generic.List[hashtable]]::new()
$inLatestSection = $false
$latestVersion = $null

foreach ($line in $detectionContent) {
    if ($line -match "^\[LATEST\]\s+([\d.]+)") {
        $latestVersion = $matches[1]
        $inLatestSection = $true
        continue
    }
    if ($inLatestSection -and $line -match "^\[L\]\s+(.+)$") {
        $latestEntries.Add(@{
            Version = $latestVersion
            Path = $matches[1].Trim()
        })
    }
    if ($inLatestSection -and $line -notmatch "^\[L\]" -and $line.Trim() -ne "") {
        $inLatestSection = $false
    }
}

# Extract Registry entries [R]
$registryEntries = [System.Collections.Generic.List[hashtable]]::new()
$inRegistrySection = $false
$currentRegEntry = $null

foreach ($line in $detectionContent) {
    if ($line -match "^\[REGISTRY\]$") {
        $inRegistrySection = $true
        continue
    }
    if ($inRegistrySection) {
        if ($line -match "^\[REGISTRY\]\s+([\d.]+)") {
            $currentRegEntry = @{
                Name = "Registry Entry"
                Version = $matches[1]
                NormalizedVersion = $matches[1]
                Location = $null
            }
            $registryEntries.Add($currentRegEntry)
        }
        elseif ($currentRegEntry -and $line -match "^\[R\]\s+(.+)$") {
            $location = $matches[1].Trim()
            if ($location -ne "(not specified)") {
                $currentRegEntry.Location = $location
            }
        }
        elseif ($line -match "^\[OUTDATED\]" -or $line -match "^-+$") {
            $inRegistrySection = $false
        }
    }
}

# Extract Outdated entries [O]
$outdatedEntries = [System.Collections.Generic.List[hashtable]]::new()
$currentOutdatedVersion = $null

foreach ($line in $detectionContent) {
    if ($line -match "^\[OUTDATED\]\s+([\d.]+)") {
        $currentOutdatedVersion = $matches[1]
        continue
    }
    if ($currentOutdatedVersion -and $line -match "^\[O\]\s+(.+)$") {
        $outdatedEntries.Add(@{
            Version = $currentOutdatedVersion
            Path = $matches[1].Trim()
        })
    }
    if ($currentOutdatedVersion -and $line -match "^-+$") {
        $currentOutdatedVersion = $null
    }
}

# Extract Abandoned entries [A] (from [EMPTY] lines or explicit [A] lines)
$abandonedEntries = [System.Collections.Generic.List[string]]::new()

foreach ($line in $detectionContent) {
    if ($line -match "^\s*\[EMPTY\]\s+(.+)$") {
        $abandonedEntries.Add($matches[1].Trim())
    }
    elseif ($line -match "^\[A\]\s+(.+)$") {
        $abandonedEntries.Add($matches[1].Trim())
    }
}

# Log what we found
$logContent.Add("")
$logContent.Add("Parsed from detection log:")
$logContent.Add("  Latest version: $(if ($latestVersion) { "$latestVersion" } else { 'NOT FOUND' })")
$logContent.Add("  Latest exe paths: $($latestEntries.Count)")
$logContent.Add("  Registry entries: $($registryEntries.Count)")
$logContent.Add("  Outdated entries: $($outdatedEntries.Count)")
$logContent.Add("  Abandoned directories: $($abandonedEntries.Count)")
$logContent.Add("----------------------------------------")

# Function to check if a path is or is under a root Adobe folder
function Test-IsRootAdobeFolder {
    param([string]$Path)
    $normalizedPath = $Path.TrimEnd('\')
    foreach ($root in $rootAdobeFolders) {
        if ($normalizedPath -eq $root) {
            return $true
        }
    }
    return $false
}

# Function to delete empty parent folders up to (and including) root Adobe folders
function Remove-EmptyParentFolders {
    param(
        [string]$StartPath,
        [int]$RemediationLevel,
        [System.Collections.Generic.HashSet[string]]$VirtuallyDeleted
    )
    
    $results = [System.Collections.Generic.List[string]]::new()
    $currentPath = Split-Path -Parent $StartPath
    
    while ($currentPath) {
        # Check if folder exists and is empty
        if (Test-Path $currentPath) {
            $contents = @(Get-ChildItem -Path $currentPath -ErrorAction SilentlyContinue)
            
            # In test mode (level 0), filter out items that have been "virtually deleted"
            if ($RemediationLevel -eq 0 -and $VirtuallyDeleted) {
                $contents = @($contents | Where-Object { -not $VirtuallyDeleted.Contains($_.FullName) })
            }
            
            if ($contents.Count -eq 0) {
                if ($RemediationLevel -eq 0) {
                    $results.Add("    WOULD DELETE empty parent: $currentPath")
                    if ($VirtuallyDeleted) {
                        [void]$VirtuallyDeleted.Add($currentPath)
                    }
                } else {
                    try {
                        Remove-Item -Path $currentPath -ErrorAction Stop
                        $results.Add("    DELETED empty parent: $currentPath")
                    } catch {
                        $results.Add("    FAILED to delete parent: $currentPath - $($_.Exception.Message)")
                        break
                    }
                }
                
                # Stop traversing after deleting a root Adobe folder
                if (Test-IsRootAdobeFolder $currentPath) {
                    $results.Add("    Reached root folder: $currentPath")
                    break
                }
                
                $currentPath = Split-Path -Parent $currentPath
            } else {
                $fileCount = ($contents | Where-Object { -not $_.PSIsContainer }).Count
                $dirCount = ($contents | Where-Object { $_.PSIsContainer }).Count
                $results.Add("    Parent not empty (has $fileCount files, $dirCount folders): $currentPath")
                break
            }
        } else {
            break
        }
    }
    
    return $results
}

$successCount = 0
$failCount = 0
$skippedCount = 0

# Track "virtually deleted" folders in test mode for accurate parent folder checks
$virtuallyDeleted = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

# ============================================
# SAFETY CHECK: Verify Latest and Registry match before removing outdated
# ============================================
$logContent.Add("")
$logContent.Add("%% SAFETY VALIDATION %%")

$safeToRemoveOutdated = $false

if ($latestEntries.Count -eq 0) {
    $logContent.Add("WARNING: No latest version entries found - cannot safely remove outdated files")
    $safeToRemoveOutdated = $false
}
elseif ($registryEntries.Count -eq 0) {
    $logContent.Add("WARNING: No registry entries found - cannot verify installation")
    $safeToRemoveOutdated = $false
}
else {
    # Check if registry version matches latest version
    $registryMatchesLatest = $false
    $registryPathMatchesLatest = $false
    
    foreach ($regEntry in $registryEntries) {
        if ($regEntry.NormalizedVersion -eq $latestVersion) {
            $registryMatchesLatest = $true
            $logContent.Add("Registry version matches latest: YES ($($regEntry.Name) v$($regEntry.NormalizedVersion))")
            
            # Check if registry install path contains latest exe paths
            if ($regEntry.Location) {
                $regLocationNorm = $regEntry.Location.TrimEnd('\')
                foreach ($latestItem in $latestEntries) {
                    if ($latestItem.Path -like "$regLocationNorm\*") {
                        $registryPathMatchesLatest = $true
                        break
                    }
                }
            }
            break
        }
    }
    
    if (-not $registryMatchesLatest) {
        $logContent.Add("Registry version matches latest: NO")
        foreach ($regEntry in $registryEntries) {
            $logContent.Add("  Registry: v$($regEntry.NormalizedVersion), Latest: v$latestVersion")
        }
    }
    
    if ($registryPathMatchesLatest) {
        $logContent.Add("Registry install path matches latest exe location: YES")
    } else {
        $logContent.Add("Registry install path matches latest exe location: NO")
    }
    
    if ($registryMatchesLatest -and $registryPathMatchesLatest) {
        $safeToRemoveOutdated = $true
        $logContent.Add("")
        $logContent.Add("VALIDATION PASSED: Safe to remove outdated files")
    } else {
        $logContent.Add("")
        $logContent.Add("VALIDATION FAILED: Will NOT remove outdated files")
    }
}

$logContent.Add("----------------------------------------")

# ============================================
# PROCESS OUTDATED FILES
# ============================================
$logContent.Add("")
$logContent.Add("%% OUTDATED FILES %%")

if ($outdatedEntries.Count -eq 0) {
    $logContent.Add("No outdated files to process.")
}
elseif ($remediationLevel -lt 2) {
    $logContent.Add("Skipping outdated file removal - remediation level is $remediationLevel (need level 2 or 3)")
    $skippedCount += $outdatedEntries.Count
}
elseif ($remediationLevel -eq 2 -and -not $safeToRemoveOutdated) {
    $logContent.Add("Skipping outdated file removal - safety validation failed (use level 3 to override)")
    $skippedCount += $outdatedEntries.Count
}
else {
    if ($remediationLevel -eq 3 -and -not $safeToRemoveOutdated) {
        $logContent.Add("WARNING: Level 3 - Proceeding without safety validation!")
    }
    
    # Group outdated entries by their containing folder
    $foldersToDelete = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    
    foreach ($entry in $outdatedEntries) {
        $folder = Split-Path -Parent $entry.Path
        [void]$foldersToDelete.Add($folder)
    }
    
    $logContent.Add("Outdated file folders to remove: $($foldersToDelete.Count)")
    $logContent.Add("")
    
    foreach ($folder in $foldersToDelete) {
        $logContent.Add("[FOLDER] $folder")
        
        # Check if folder exists
        if (-not (Test-Path $folder)) {
            $logContent.Add("    SKIPPED: Folder no longer exists")
            $skippedCount++
            continue
        }
        
        # Make sure we're not deleting a folder that contains latest files
        $containsLatest = $false
        foreach ($latestItem in $latestEntries) {
            if ($latestItem.Path -like "$folder\*") {
                $containsLatest = $true
                $logContent.Add("    SKIPPED: Contains latest version file: $($latestItem.Path)")
                break
            }
        }
        
        if ($containsLatest) {
            $skippedCount++
            continue
        }
        
        # Delete the folder
        if ($remediationLevel -eq 0) {
            $logContent.Add("    WOULD DELETE folder")
            [void]$virtuallyDeleted.Add($folder)
            $successCount++
        } else {
            try {
                Remove-Item -Path $folder -Recurse -ErrorAction Stop
                $logContent.Add("    DELETED folder")
                $successCount++
            } catch {
                $logContent.Add("    FAILED: $($_.Exception.Message)")
                $failCount++
                continue
            }
        }
        
        # Clean up empty parent folders
        $parentResults = Remove-EmptyParentFolders -StartPath $folder -RemediationLevel $remediationLevel -VirtuallyDeleted $virtuallyDeleted
        foreach ($result in $parentResults) {
            $logContent.Add($result)
        }
    }
}

$logContent.Add("----------------------------------------")

# ============================================
# PROCESS ABANDONED DIRECTORIES
# ============================================
$logContent.Add("")
$logContent.Add("%% ABANDONED DIRECTORIES %%")

if ($abandonedEntries.Count -eq 0) {
    $logContent.Add("No abandoned directories to process.")
}
elseif ($remediationLevel -eq 0) {
    $logContent.Add("Test mode - would process $($abandonedEntries.Count) abandoned directories")
    foreach ($dir in $abandonedEntries) {
        $logContent.Add("[ABANDONED] $dir")
        if (Test-Path $dir) {
            $logContent.Add("    WOULD DELETE directory")
            [void]$virtuallyDeleted.Add($dir)
            $successCount++
            
            # Clean up empty parent folders
            $parentResults = Remove-EmptyParentFolders -StartPath $dir -RemediationLevel $remediationLevel -VirtuallyDeleted $virtuallyDeleted
            foreach ($result in $parentResults) {
                $logContent.Add($result)
            }
        } else {
            $logContent.Add("    SKIPPED: Directory no longer exists")
            $skippedCount++
        }
    }
}
else {
    foreach ($dir in $abandonedEntries) {
        $logContent.Add("[ABANDONED] $dir")
        
        # Check if directory exists
        if (-not (Test-Path $dir)) {
            $logContent.Add("    SKIPPED: Directory no longer exists")
            $skippedCount++
            continue
        }
        
        # Verify directory is still empty
        $contents = @(Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue)
        if ($contents.Count -gt 0) {
            $logContent.Add("    SKIPPED: Directory no longer empty ($($contents.Count) files found)")
            $skippedCount++
            continue
        }
        
        # Delete the directory (no -Recurse or -Force as failsafe - should be empty)
        try {
            Remove-Item -Path $dir -ErrorAction Stop
            $logContent.Add("    DELETED directory")
            $successCount++
        } catch {
            $logContent.Add("    FAILED: $($_.Exception.Message)")
            $failCount++
            continue
        }
        
        # Clean up empty parent folders
        $parentResults = Remove-EmptyParentFolders -StartPath $dir -RemediationLevel $remediationLevel -VirtuallyDeleted $virtuallyDeleted
        foreach ($result in $parentResults) {
            $logContent.Add($result)
        }
    }
}

$logContent.Add("----------------------------------------")

# ============================================
# SUMMARY
# ============================================
$logContent.Add("")
if ($remediationLevel -eq 0) {
    $logContent.Add("Summary (TEST MODE - Level 0): $successCount would be processed, $skippedCount skipped, $failCount failed")
} else {
    $logContent.Add("Summary (Level $remediationLevel): $successCount processed, $skippedCount skipped, $failCount failed")
}

# Write log
$outputText = $logContent -join "`n"
$outputText | Out-File -FilePath $logFile -Force -Encoding UTF8

# Output for Intune
Write-Host $outputText

if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}