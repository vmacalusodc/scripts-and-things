param(
    [string]$Script,
    [int]$Admin=0,
    [int]$Debug=1
)

function Write-DebugInfo {
	param(
	[string]$text
	)

	if ($Debug -eq 1) {
	Write-Host "Debug: $text"
	}
}



. "$PSScriptRoot\inc_Pause.ps1"

Write-DebugInfo "RunScript.ps1 received: Script='$Script' Admin=$Admin"

# Are we elevated?
$IsAdmin = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    # Use the exact current host exe (pwsh.exe or powershell.exe)
    $hostExe = ([System.Diagnostics.Process]::GetCurrentProcess()).MainModule.FileName
    if (-not (Test-Path $hostExe)) { $hostExe = (Get-Command powershell).Source } # fallback

    # Rebuild arguments for THIS script. Avoid -NoExit so the elevated window doesn't linger unnecessarily.
    $wd = (Get-Location).Path
    $argsList = @(
        '-NoProfile'
        '-ExecutionPolicy','Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        # pass your own params back in:
        '-Script', ('"{0}"' -f ($Script -replace '"','`"'))
        '-Admin','1'
    )

    # Forward any extras
    if ($args) {
        foreach ($a in $args) { $argsList += ('"{0}"' -f ($a -replace '"','`"')) }
    }

    # Launch elevated in same working directory, then exit current (non-admin) process.
    $p = Start-Process -FilePath $hostExe `
        -ArgumentList $argsList `
        -Verb RunAs `
        -WorkingDirectory $wd `
        -PassThru

    # Optional: wait for the elevated run to finish, then exit
    if ($p) { $p.WaitForExit() }
    exit
}


# Normalize the target script name and path
if ([IO.Path]::GetExtension($Script) -ne '.ps1') { $Script = "$Script.ps1" }
$target = Join-Path $PSScriptRoot $Script

if (-not (Test-Path $target)) {
    Write-DebugInfo "ERROR: Target script not found: $target" -ForegroundColor Red
    Show-Pause
    exit 1
}

Write-DebugInfo "RunScript: Invoking '$target' (Admin=$Admin)" -ForegroundColor Green
try {
    & $target
} catch {
    Write-DebugInfo "ERROR running target: $($_.Exception.Message)" -ForegroundColor Red
}

Show-Pause
exit
