# Version 1.00 (7/14/2025)
# * Initial Release
# * Backup and Restore taskbar pinned icons
# Version 1.10 (7/14/2025)
# * Added option to select from available backups.
#
# Vincent Macaluso (R3)

function Get-SerialNumber {
    $serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    return $serial.Trim()
}

function Backup-Taskbar {
    $serial = Get-SerialNumber
    $baseDir = Join-Path -Path (Get-Location) -ChildPath "taskbartool"
    $backupDir = Join-Path -Path $baseDir -ChildPath $serial
    $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    $regBackup = Join-Path -Path $backupDir -ChildPath "taskband.reg"

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    Copy-Item -Path "$taskbarPath\*" -Destination $backupDir -Recurse -Force
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" $regBackup /y

    Write-Host "Backup completed and saved to: $backupDir"
}

function Restore-Taskbar {
    $baseDir = Join-Path -Path (Get-Location) -ChildPath "taskbartool"
    if (-not (Test-Path $baseDir)) {
        Write-Host "No backups found."
        return
    }

    $backups = Get-ChildItem -Path $baseDir -Directory
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

    $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    $regBackup = Join-Path -Path $selectedBackup -ChildPath "taskband.reg"

    if (-not (Test-Path $taskbarPath)) {
        New-Item -ItemType Directory -Path $taskbarPath -Force | Out-Null
    }

    Copy-Item -Path "$selectedBackup\*.lnk" -Destination $taskbarPath -Force
    reg import $regBackup

    Stop-Process -Name explorer -Force
    Start-Process explorer

    Write-Host "Restore completed from: $selectedBackup"
}

function Show-Menu {
    Clear-Host
    Write-Host "=== Taskbar Backup & Restore ==="
    Write-Host "1. Backup Taskbar"
    Write-Host "2. Restore Taskbar"
    Write-Host "3. Exit"
}

do {
    Show-Menu
    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" { Backup-Taskbar }
        "2" { Restore-Taskbar }
        "3" { Write-Host "Exiting..."; exit }
        default { Write-Host "Invalid choice. Please select 1, 2, or 3." }
    }

    Pause
} while ($true)
