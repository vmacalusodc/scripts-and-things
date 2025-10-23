Write-Host ":: This Supposedly Will Sync Device Like From Company Portal ::" -ForegroundColor Cyan


###Get-ScheduledTask | Where-Object {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask

$Shell = New-Object -ComObject Shell.Application
$Shell.open("intunemanagementextension://syncapp")

Write-Host ":: " -ForegroundColor Cyan -NoNewline
Write-Host "Press ENTER Key To Exit" -ForegroundColor Magenta -NoNewline
Write-Host " ::"-ForegroundColor Cyan -NoNewline
Read-Host 