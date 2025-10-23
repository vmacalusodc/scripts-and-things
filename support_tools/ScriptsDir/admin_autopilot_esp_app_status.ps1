# Check for admin
$isAdmin = [System.Security.Principal.WindowsPrincipal]::new(
    [System.Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole('Administrators')

if(-not $isAdmin) {
    $params = @{
        FilePath     = 'powershell' # or pwsh if Core
        Verb         = 'RunAs'
        ArgumentList = @(
            '-NoExit'
            '-ExecutionPolicy ByPass'
            '-File "{0}"' -f $PSCommandPath
        )
    }

    Start-Process @params
    return
}

# Check Intune Win32 app install status from registry
$regPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps"
if (Test-Path $regPath) {
    Get-ChildItem -Path $regPath | ForEach-Object {
        $appKey = $_.Name
        $result = Get-ItemProperty -Path $_.PSPath
        [PSCustomObject]@{
            AppId      = Split-Path $appKey -Leaf
            Name       = $result.DisplayName
            InstallCmd = $result.InstallCommandLine
            ExitCode   = $result.ExitCode
            Result     = $result.InstallResultCode
            Timestamp  = $result.LastModifiedDateTime
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "Win32Apps registry path not found." -ForegroundColor Red
}


# pause prompt
Write-Host ":: " -ForegroundColor Cyan -NoNewline
Write-Host "Press ENTER Key To Exit" -ForegroundColor Magenta -NoNewline
Write-Host " ::"-ForegroundColor Cyan -NoNewline
Read-Host 

exit