> [!CAUTION]
>  As with everything you find online - read over the source and **use with caution**
>  These worked for me but I can't guarantee shit won't break for you

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
