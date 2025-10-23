Clear-Host
Write-Host
Write-Host ':: Resetting Automox Notifications ::' -ForegroundColor White -BackgroundColor Red

amagent notifications remove --all

Write-Host ":: " -ForegroundColor Cyan -NoNewline
Write-Host "Press ENTER Key To Exit" -ForegroundColor Magenta -NoNewline
Write-Host " ::"-ForegroundColor Cyan -NoNewline
Read-Host 