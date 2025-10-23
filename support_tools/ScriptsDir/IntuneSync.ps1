#Get-ScheduledTask | ? {$_.TaskName -eq ‘PushLaunch’} | Start-ScheduledTask
#net stop IntuneManagementExtension && net start IntuneManagementExtension
#

Write-Host ":: This Supposedly Will Sync Device Like From Company Portal ::" -ForegroundColor Cyan


#$EnrollmentID = Get-ScheduledTask | Where-Object { $_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt\*" } | Select-Object -ExpandProperty TaskPath -Unique | Where-Object { $_ -like "*-*-*" } | Split-Path -Leaf
#Start-Process -FilePath "C:\Windows\system32\deviceenroller.exe" -Wait -ArgumentList "/o $EnrollmentID /c /b"

###Get-ScheduledTask | Where-Object {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask

$Shell = New-Object -ComObject Shell.Application
$Shell.open("intunemanagementextension://syncapp")

Write-Host ":: " -ForegroundColor Cyan -NoNewline
Write-Host "Press ENTER Key To Exit" -ForegroundColor Magenta -NoNewline
Write-Host " ::"-ForegroundColor Cyan -NoNewline
Read-Host 