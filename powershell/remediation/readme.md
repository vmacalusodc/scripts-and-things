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
       - Verifies max log size matches target (200 MB)
       - Counts existing archive files against max threshold (3)
       - Reports archive file sizes and ages
       - Logs to C:\R3-IT\SecurityLogRotationDetection.log
  - ***Remediate-SecurityLogRotation.ps1:***
       - Sets Security event log to AutoBackup rotation mode
       - Configures max log size to 200 MB
       - Deletes oldest archives when count exceeds limit (keeps 3 newest)
       - Logs to C:\R3-IT\SecurityLogRotationRemediation.log
