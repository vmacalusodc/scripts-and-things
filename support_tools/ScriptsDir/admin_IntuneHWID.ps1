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

$SerialNumber = (Get-WmiObject -class win32_bios).Serialnumber
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
Install-Script -Name Get-WindowsAutopilotInfo
Get-WindowsAutopilotInfo -OutputFile "$PSScriptRoot\IntuneHWID\$SerialNumber.csv"
Write-Host
Write-Host "Saved to $PSScriptRoot\IntuneHWID\$SerialNumber.csv"

Write-Host ":: " -ForegroundColor Cyan -NoNewline
Write-Host "Press ENTER Key To Exit" -ForegroundColor Magenta -NoNewline
Write-Host " ::"-ForegroundColor Cyan -NoNewline
Read-Host 