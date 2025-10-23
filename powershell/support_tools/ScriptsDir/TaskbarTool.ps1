function Get-SerialNumber {
    $serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    return $serial.Trim()
}

    $serial = Get-SerialNumber
    $desktop = [Environment]::GetFolderPath('Desktop')
    $scriptDir = $PSScriptRoot
    $subDirectory = "TaskbarTool"
    $baseDirDesktop = Join-Path -Path $desktop -ChildPath $subDirectory
    $baseDir = Join-Path -Path $scriptDir -ChildPath $subDirectory
    $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"


function Backup-Taskbar {
    param (
    [string]$Path=$baseDir
    )
    Write-Host "Backing up to $Path"
    $backupDir = Join-Path -Path $Path -ChildPath $serial
    $regBackup = Join-Path -Path $backupDir -ChildPath "taskband.reg"

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    Copy-Item -Path "$taskbarPath\*" -Destination $backupDir -Recurse -Force
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" $regBackup /y

    Write-Host "Backup completed and saved to: $backupDir"
	pause
}

function Restore-Taskbar {
     param (
    [string]$Path=$baseDir
    )

    $backupDir = Join-Path -Path $Path -ChildPath $serial
    $regBackup = Join-Path -Path $backupDir -ChildPath "taskband.reg"

    if (-not (Test-Path $Path)) {
        Write-Host "No backups found."
	    pause
        return
    }

    $backups = Get-ChildItem -Path $Path -Directory
    if ($backups.Count -eq 0) {
        Write-Host "No backups available."
        return
    }

    Write-Host "Available Backups:"
    for ($i = 0; $i -lt $backups.Count; $i++) {
        Write-Host "$($i + 1). $($backups[$i].Name)"
    }

    $selection = Read-Host "Enter the number of the backup to restore"
    if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $backups.Count) {
        $selectedBackup = $backups[$selection - 1].FullName
    } else {
        Write-Host "Invalid selection."
        return
    }

    if (-not (Test-Path $taskbarPath)) {
        New-Item -ItemType Directory -Path $taskbarPath -Force | Out-Null
    }

    Copy-Item -Path "$selectedBackup\*.lnk" -Destination $taskbarPath -Force
    reg import $regBackup

    Stop-Process -Name explorer -Force
    Start-Process explorer

    Write-Host "Restore completed from: $selectedBackup"
    pause
}

function Show-Menu {
    Clear-Host
    Write-Host "=== Taskbar Backup & Restore ===" -ForegroundColor Magenta
    Write-Host "1. Backup Taskbar To Script Directory" -ForegroundColor Cyan
    Write-Host "2. Backup Taskbar To Desktop" -ForegroundColor Cyan
    Write-Host "3. Restore Taskbar from Script Directory" -ForegroundColor Cyan
    Write-Host "4. Restore Taskbar from Desktop" -ForegroundColor Cyan
    Write-Host
    Write-Host "Script Dir : $baseDir" -ForegroundColor DarkGray
    Write-Host "Desktop Dir: $baseDirDesktop" -ForegroundColor DarkGray
    Write-Host
    Write-Host "Any other key to exit." -ForegroundColor Cyan
    Write-Host 
    Write-Host "[1,2,3,4]: " -NoNewline -ForegroundColor Magenta
}

do {
    Show-Menu
    $selection = [Console]::ReadKey($true)
    $choice = $selection.KeyChar
    Write-Host "You chose $([char]::ToUpperInvariant($choice))"
    Write-Host

    switch ($choice) {
        "1" { Backup-Taskbar -Path $baseDir }
	    "2" { Backup-Taskbar -Path $baseDirDesktop }
        "3" { Restore-Taskbar -Path $baseDir }
        "4" { Restore-Taskbar -Path $baseDirDesktop }
        default { Write-Host "Exiting..."; Write-Host; exit }
    }


} while ($true)
