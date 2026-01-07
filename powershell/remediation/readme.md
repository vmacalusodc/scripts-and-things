## powershell/remediation
- Some detection & remediation scripts I wrote.

### **AbandonedAdobeDirs**
  - ***Detect-AbandonedAdobeDirs.ps1:***
       - Scans Program Files for empty or abandoned Adobe Acrobat/Reader directories
       - Checks registry for installed Adobe Acrobat/Reader entries and versions
       - Extracts version info from Adobe executables (Acrobat.exe, AcroRd32.exe, etc.)
       - Compares found versions against target version and identifies outdated installs
       - Detects low-file-count directories that may contain only leftover installers
       - Logs to C:\R3-IT\AdobeDetection.log
  - ***Remediate-AbandonedAdobeDirs.ps1:***
       - Parses detection log to identify abandoned directories and outdated files
       - Supports 4 remediation levels (0=test, 1=empty dirs only, 2=with validation, 3=aggressive)
       - Validates registry version matches latest before removing outdated files (level 2)
       - Protects folders containing latest version executables from deletion
       - Cleans up empty parent folders after removing content
       - Logs to C:\R3-IT\AdobeRemediation.log
  - ***Remediation-AbandonedAdobeDirs-GroupBased.ps1:***
       - This was a WIP that I haven't tested much, so I can't vouch for it.
       - Same functionality as standard remediation script
       - Automatically detects which Intune group triggered execution
       - Sets remediation level based on group membership (configurable mapping)
       - Attempts detection via Intune registry, SideCar policies, IME logs, environment variables, and command line args
       - Falls back to safe default level (0) if group cannot be determined
       - Logs detection method used for troubleshooting

### **OutdatedDotNet**
  - ***Detect-OutdatedDotNet.ps1:***
     - Scans for end-of-life .NET runtimes via registry and file system
     - Identifies developer machines (Visual Studio, VS Code, Rider, SDKs installed)
     - Checks if EOL runtimes are actively loaded by running processes
     - Reports last access times to identify unused vs actively used runtimes
     - Logs to C:\R3-IT\DotNetDetection.log
  - ***Remediate-OutdatedDotNet.ps1:***
       - Uninstalls EOL .NET runtimes using registry uninstall commands
       - Skips developer machines when SkipDeveloperMachines is enabled
       - Skips runtimes currently loaded by running processes
       - Handles both bundle EXE and MSI uninstall methods
       - Cleans up orphaned folders if uninstaller is missing
       - Logs to C:\R3-IT\DotNetRemediation.log

### **SecurityLogRotation**
  - ***Detect-SecurityLogRotation.ps1:***
       - Checks if Security event log is set to AutoBackup mode
       - Verifies max log size matches target (192 MB)
       - Counts existing archive files against max threshold (3)
       - Reports archive file sizes and ages
       - Logs to C:\R3-IT\SecurityLogRotationDetection.log
  - ***Remediate-SecurityLogRotation.ps1:***
       - Sets Security event log to AutoBackup rotation mode
       - Configures max log size to 192 MB
       - Deletes oldest archives when count exceeds limit (keeps 3 newest)
       - Logs to C:\R3-IT\SecurityLogRotationRemediation.log

### **TeamsClassic**
  - ***Detect-TeamsClassic.ps1:***
       - Detects Microsoft Teams Classic installations across multiple locations
       - Checks Win32_Product for Machine-Wide Installer (excludes Office Add-in)
       - Scans registry uninstall entries for Teams (excludes Meeting Add-in)
       - Searches all user profiles for per-user Teams installations
       - Checks common installation paths and winget package list
       - Logs excluded items (add-ins kept installed) for transparency
       - Logs to C:\R3-IT\Detect-TeamsClassic.log
  - ***Remediate-TeamsClassic.ps1:***
       - Stops all running Teams processes before uninstallation
       - Uninstalls Machine-Wide Installer via MSI product code
       - Runs per-user uninstaller (Update.exe --uninstall) for each user profile
       - Removes leftover Teams folders from AppData and Program Files
       - Cleans up registry entries while preserving Office Meeting Add-in
       - Logs to C:\R3-IT\Remediate-TeamsClassic.log

### **VSCODE**
  - ***Detect-VSCODE.ps1:***
       - Detects all Visual Studio Code installations (excludes Insiders builds)
       - Checks registry uninstall entries for system and user installs
       - Scans all user profiles for per-user VS Code installations
       - Extracts version info from Code.exe file properties
       - Compares installed versions against minimum required version (1.104.0)
       - Writes installation details to VSCodeInstallations.txt for remediation script
       - Logs to C:\R3-IT\Detect-VSCODE.log
  - ***Remediate-VSCODE.ps1:***
       - Reads installation list from detection script output
       - Downloads appropriate installer (user vs system) from official VS Code URL
       - Runs silent install with /VERYSILENT /MERGETASKS=!runcode flags
       - Allows installer to handle running VS Code instances (no forced process kill)
       - Verifies new version after installation completes
       - Reports success/failure counts for multiple installations
       - Logs to C:\R3-IT\Remediate-VSCODE.log

### **WinGet**
  - ***Detect-WinGet.ps1:***
       - Checks for available winget package upgrades
       - Maintains exclusion list (e.g., Microsoft.Teams.Classic) written to WinGetExclude.txt
       - Detects Intune-managed applications via registry
       - Identifies conflicts between Intune-managed and winget-tracked apps
       - Filters progress bars and spinner characters from winget output
       - Logs full winget list and upgrade output for troubleshooting
       - Logs to C:\R3-IT\Detect-WinGet.log
  - ***Remediate-WinGet.ps1:***
       - Reads exclusion list from detection script output
       - Parses winget upgrade output to extract package IDs
       - Upgrades each package individually with silent flags
       - Skips packages in exclusion list
       - Reports success/failure/skipped counts per package
       - Cleans progress bar artifacts from output logging
       - Logs to C:\R3-IT\Remediate-WinGet.log
