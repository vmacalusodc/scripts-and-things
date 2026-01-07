# Scripts and Things
* This is a collection of works related scripts I've written.

> [!CAUTION]
>  - As with everything you find online - read over the source and <ins>*use with caution*</ins>
>  - These worked for me but I can't guarantee shit won't break for you

## [./Powershell/Remediation](powershell/remediation)
## Remediation Scripts
### **AbandonedAdobeDirs**
  - ***Detect-AbandonedAdobeDirs.ps1:***
       - Scans Program Files for empty or abandoned Adobe Acrobat/Reader directories
       - Checks registry for installed Adobe Acrobat/Reader entries and versions
       - Extracts version info from Adobe executables (Acrobat.exe, AcroRd32.exe, etc.)
       - Compares found versions against target version and identifies outdated installs
       - Detects low-file-count directories that may contain only leftover installers
       - Logs to C:R3-ITAdobeDetection.log
  - ***Remediate-AbandonedAdobeDirs.ps1:***
       - Parses detection log to identify abandoned directories and outdated files
       - Supports 4 remediation levels (0=test, 1=empty dirs only, 2=with validation, 3=aggressive)
       - Validates registry version matches latest before removing outdated files (level 2)
       - Protects folders containing latest version executables from deletion
       - Cleans up empty parent folders after removing content
       - Logs to C:R3-ITAdobeRemediation.log
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
     - Logs to C:R3-ITDotNetDetection.log
  - ***Remediate-OutdatedDotNet.ps1:***
       - Uninstalls EOL .NET runtimes using registry uninstall commands
       - Skips developer machines when SkipDeveloperMachines is enabled
       - Skips runtimes currently loaded by running processes
       - Handles both bundle EXE and MSI uninstall methods
       - Cleans up orphaned folders if uninstaller is missing
       - Logs to C:R3-ITDotNetRemediation.log

### **SecurityLogRotation**
  - ***Detect-SecurityLogRotation.ps1:***
       - Checks if Security event log is set to AutoBackup mode
       - Verifies max log size matches target (192 MB)
       - Counts existing archive files against max threshold (3)
       - Reports archive file sizes and ages
       - Logs to C:R3-ITSecurityLogRotationDetection.log
  - ***Remediate-SecurityLogRotation.ps1:***
       - Sets Security event log to AutoBackup rotation mode
       - Configures max log size to 192 MB
       - Deletes oldest archives when count exceeds limit (keeps 3 newest)
       - Logs to C:R3-ITSecurityLogRotationRemediation.log

### **TeamsClassic**
  - ***Detect-TeamsClassic.ps1:***
       - Detects Microsoft Teams Classic installations across multiple locations
       - Checks Win32_Product for Machine-Wide Installer (excludes Office Add-in)
       - Scans registry uninstall entries for Teams (excludes Meeting Add-in)
       - Searches all user profiles for per-user Teams installations
       - Checks common installation paths and winget package list
       - Logs excluded items (add-ins kept installed) for transparency
       - Logs to C:R3-ITDetect-TeamsClassic.log
  - ***Remediate-TeamsClassic.ps1:***
       - Stops all running Teams processes before uninstallation
       - Uninstalls Machine-Wide Installer via MSI product code
       - Runs per-user uninstaller (Update.exe --uninstall) for each user profile
       - Removes leftover Teams folders from AppData and Program Files
       - Cleans up registry entries while preserving Office Meeting Add-in
       - Logs to C:R3-ITRemediate-TeamsClassic.log

### **VSCODE**
  - ***Detect-VSCODE.ps1:***
       - Detects all Visual Studio Code installations (excludes Insiders builds)
       - Checks registry uninstall entries for system and user installs
       - Scans all user profiles for per-user VS Code installations
       - Extracts version info from Code.exe file properties
       - Compares installed versions against minimum required version (1.104.0)
       - Writes installation details to VSCodeInstallations.txt for remediation script
       - Logs to C:R3-ITDetect-VSCODE.log
  - ***Remediate-VSCODE.ps1:***
       - Reads installation list from detection script output
       - Downloads appropriate installer (user vs system) from official VS Code URL
       - Runs silent install with /VERYSILENT /MERGETASKS=!runcode flags
       - Allows installer to handle running VS Code instances (no forced process kill)
       - Verifies new version after installation completes
       - Reports success/failure counts for multiple installations
       - Logs to C:R3-ITRemediate-VSCODE.log

### **WinGet**
  - ***Detect-WinGet.ps1:***
       - Checks for available winget package upgrades
       - Maintains exclusion list (e.g., Microsoft.Teams.Classic) written to WinGetExclude.txt
       - Detects Intune-managed applications via registry
       - Identifies conflicts between Intune-managed and winget-tracked apps
       - Filters progress bars and spinner characters from winget output
       - Logs full winget list and upgrade output for troubleshooting
       - Logs to C:R3-ITDetect-WinGet.log
  - ***Remediate-WinGet.ps1:***
       - Reads exclusion list from detection script output
       - Parses winget upgrade output to extract package IDs
       - Upgrades each package individually with silent flags
       - Skips packages in exclusion list
       - Reports success/failure/skipped counts per package
       - Cleans progress bar artifacts from output logging
       - Logs to C:R3-ITRemediate-WinGet.log

## [./Powershell/Support_tools](powershell/support_tools)
> [!CAUTION]
>  - As with everything you find online - read over the source and <ins>*use with caution*</ins>
>  - These worked for me but I can't guarantee shit won't break for you

## powershell/support_tools

- All scripts can be run directly from the Scripts directory, but I created a .cmd file wrapper for each of them at the root level of support_tools so that you can just double click on them from the File Manager. Any file that contains admin will need administrator escalation.

- All of the wrapper files are copies of each other, they each check to see if the name of itself contains admin or not, and then calls a run_script.ps1 file in the scriptsdir, passes it's own name and if admin is needed. Run_script.ps1 in turn runs the matching ps1 script. This was done this way to prevent some sort of nuisance and I don't remember what. lol

### **/** (.cmd wrappers)
  - ***DriveMapper.cmd:***
    - Launches DriveMapper.ps1 (no admin required)

  - ***IntuneSync.cmd:***
    - Launches IntuneSync.ps1 (no admin required)

  - ***SecurePrint_Install.cmd:***
    - Launches SecurePrint_Install.ps1 (no admin required)

  - ***TaskbarTool.cmd:***
    - Launches TaskbarTool.ps1 (no admin required)

  - ***RemoveOneDriveRegKey.cmd:***
    - Displays instructions to run from a network share location
    - Does not call RunScript.ps1

  - ***RunCmd.cmd:***
    - Alternative wrapper that accepts script name and admin flag as arguments
    - Sets execution policy to Unrestricted

  - ***admin_FixStuckAutomox.cmd:***
    - Launches admin_FixStuckAutomox.ps1 (auto-elevates to admin)

  - ***admin_IntuneHWID.cmd:***
    - Launches admin_IntuneHWID.ps1 (auto-elevates to admin)

  - ***admin_UpdateWindows.cmd:***
    - Launches admin_UpdateWindows.ps1 (auto-elevates to admin)

  - ***admin_UpdateWindows2.cmd:***
    - Launches admin_UpdateWindows2.ps1 (auto-elevates to admin)

  - ***admin_autopilot_esp_app_status.cmd:***
    - Launches admin_autopilot_esp_app_status.ps1 (auto-elevates to admin)

### **/ScriptsDir**
  - ***RunScript.ps1:***
    - Entry point for all .cmd wrappers
    - Auto-elevates to administrator if needed
    - Locates and executes the matching .ps1 script by name
    - Includes debug output and pause on completion

  - ***inc_Pause.ps1:***
    - Shared include file for pause prompts
    - Randomizes bullet styles and colors for visual variety

  - ***DriveMapper.ps1:***
    - GUI tool for mapping/unmapping network drives
    - Displays current drive status (Mapped, Available, No Access)
    - Backup current drive mappings to file (by username + serial number)
    - Restore drive mappings from backup files
    - Prevents conflicts when multiple paths use the same drive letter

  - ***IntuneSync.ps1:***
    - Triggers an Intune sync via the intunemanagementextension:// protocol
    - Same effect as clicking "Sync" in Company Portal

  - ***SecurePrint_Install.ps1:***
    - Installs a network printer from a print server
    - Tests connectivity before attempting install
    - Checks if printer is already installed and offers reinstall option
    - Requires on-premises network (not VPN)

  - ***TaskbarTool.ps1:***
    - Backs up and restores Windows taskbar pinned items
    - Saves shortcuts and registry keys by device serial number
    - Supports backup/restore to script directory or desktop

  - ***UpdateWindows2.ps1:***
    - Menu-driven Windows Update tool (non-admin version)
    - Installs updates via PSWindowsUpdate module
    - Options to open Windows Update control panel
    - Includes Autopilot attestation test and TPM clear options

  - ***admin_FixStuckAutomox.ps1:***
    - Clears stuck Automox notifications using amagent CLI
    - Requires admin elevation

  - ***admin_IntuneHWID.ps1:***
    - Exports Windows Autopilot hardware ID to CSV
    - Uses Get-WindowsAutopilotInfo script
    - Saves to IntuneHWID folder with serial number filename

  - ***admin_UpdateWindows.ps1:***
    - Menu-driven Windows Update tool (admin version)
    - Same options as UpdateWindows2 but runs elevated

  - ***admin_UpdateWindows2.ps1:***
    - Enhanced Windows Update tool with confirmation prompts
    - Checks for existing modules before installing
    - Shows update count before proceeding
    - Includes detailed warnings for TPM clear operation

  - ***admin_autopilot_esp_app_status.ps1:***
    - Queries Intune Win32 app install status from registry
    - Displays app ID, name, install command, exit code, and timestamp
    - Useful for troubleshooting Enrollment Status Page (ESP) issues
