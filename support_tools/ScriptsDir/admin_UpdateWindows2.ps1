function Confirm-ContinueN {
    param (
        [string]$message = "Continue"
    )
    # Prompt with default = N
    do {
        $r = Read-Host " $message (y/N)"
        if (-not $r) { $r = 'N' }
    } until ($r -match '^[YyNn]$')

    if ($r -notmatch '^[Yy]$') {
        Write-Host " Aborted." -ForegroundColor Red
        exit
    }
    Write-Host " OK" -ForegroundColor Green
}

function Confirm-ContinueY {
    param (
        [string]$message = "Continue"
    )
    # Prompt with default = Y
    do {
        $r = Read-Host " $message (Y/n)"
        if (-not $r) { $r = 'Y' }
    } until ($r -match '^[YyNn]$')

    if ($r -notmatch '^[Yy]$') {
        Write-Host " Aborted." -ForegroundColor Red
        exit
    }
    Write-Host " OK" -ForegroundColor Green
}


# making the background black so it's not as ugly
$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host
Write-Host
Write-Host ':: Upgrade Windows / TPM Tools ::' -ForegroundColor Cyan
Write-Host
Write-Host ' 1: Upgrade Windows (via Powershell)' -ForegroundColor Magenta
Write-Host ' 2: Upgrade Windows (via Windows Check For Updates)' -ForegroundColor Magenta
Write-Host '    This option will not work via backstage.' -ForegroundColor DarkGray
Write-Host ' 3: Run Autopilot Test Attestation ' -ForegroundColor Magenta
Write-Host '    Do not run unless you know you want to.' -ForegroundColor DarkGray
Write-Host ' 4: Clear TPM' -ForegroundColor Magenta
Write-Host '    Do not run unless you know you want to.' -ForegroundColor DarkGray
Write-Host ' Q: Quit' -ForegroundColor Magenta
Write-Host '    So soon?' -ForegroundColor DarkGray
Write-Host
Write-Host ":: CMD: "  -NoNewline -ForegroundColor Cyan
$selection = [Console]::ReadKey($true)
$choice = $selection.KeyChar
Write-Host "You chose $([char]::ToUpperInvariant($choice))"
Write-Host 
switch ($choice){
    1{# Upgrade Windows (Via Powershell)
        Write-Host
        Write-Host "You may see an warning or two - you may ignore these as long as it works. :)" -ForegroundColor Green
        Write-Host
        Start-Sleep -Seconds 2

        Write-Host "Installing packages..." -ForegroundColor Magenta
        Write-Host " Checking NuGet version..." -ForegroundColor Cyan -NoNewline
        $nuGetVersion = (Get-PackageProvider -Name NuGet).version
        $nuGetMinVersion = 2.8.5.201
        if (-not (Get-PackageProvider -Name NuGet).version -lt 2.8.5.201 ) {
            Write-Host " $nuGetVersion < $nuGetMinVersion"
            Write-Host " Updating Nuget"
            Install-PackageProvider -Name Nuget -minimumVersion 2.8.5.201 -Force 
        } else { Write-Host " OK" -ForegroundColor Green }

        Write-Host " Checking for PowerShellGet..." -NoNewline -ForegroundColor Cyan
        if(-not (Get-Module PowerShellGet -ListAvailable)){
            Write-Host " Installing..." -ForegroundColor Green
            Install-Module PowerShellGet -Scope CurrentUser -Force 
            } else { Write-Host " OK" -ForegroundColor Green }
        #Install-Module -Name PowerShellGet -Force -AllowClobber -Scope CurrentUser 
        Import-Module PowerShellGet

        Write-Host " Checking for PSWindowsUpdate..." -NoNewline -ForegroundColor Cyan
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        if(-not (Get-Module PSWindowsUpdate -ListAvailable)){
            Write-Host " Installing..." -ForegroundColor Green
            Install-Module PSWindowsUpdate -Scope CurrentUser -Force
            } else { Write-Host " OK" -ForegroundColor Green }

        #Install-Module PSWindowsUpdate -AllowClobber -Force -Scope CurrentUser
        Write-Host
        Write-Host "Getting list of updates..." -ForegroundColor Magenta
        $pendingCount = 0
        $pendingCount = (Get-WindowsUpdate).Count
        Write-Host " Found a total of $pendingCount updates."
            If ($pendingCount -gt 0 ) {
                Confirm-ContinueY
                Write-Host " Installing Updates..." -ForegroundColor Green
                Get-windowsupdate -Microsoftupdate -acceptall -install -ignorereboot
            } else {
                Write-Host " No updates to install. :(" -ForegroundColor Cyan
            }

        }
        
    2{# Upgrade Windows (via Windows Check For Updates)
        Write-Host
        Write-Host "Trying to open the Windows Control Panel... If you don't see it, it didn't work." -ForegroundColor Magenta
        Write-Host
        Start-Sleep -Seconds 2
        control update
        }
    3{# Run Autopilot Test Attestation
        Write-Host 
        Write-Host " = Testing TPM Attestation for AutoPilot = " -ForegroundColor Magenta
        Write-Host
        Write-Host "This will..." -ForegroundColor Magenta
        Write-Host "* Collect TPM attestation information from the local machine (things like the endorsement key and device identity)." -ForegroundColor Cyan
        Write-Host "* Check that the TPM is available, initialized, and supports attestation." -ForegroundColor Cyan
        Write-Host "* Verify whether the machine can successfully generate and submit an attestation blob (the proof packet)." -ForegroundColor Cyan
        Write-Host "* Return results that indicate whether the device passes or fails Autopilot attestation prerequisites." -ForegroundColor Cyan
        Write-Host
        Confirm-ContinueY
        Write-Host
        Write-Host " Checking for AutopilotTestAttestation..." -NoNewline -ForegroundColor Cyan
        if(-not (Get-Module AutopilotTestAttestation -ListAvailable)){
            Write-Host " Installing..." -ForegroundColor Green
            Install-Module AutopilotTestAttestation -Scope CurrentUser -Force 
            } else { Write-Host " OK" -ForegroundColor Green }

        #Install-Module AutopilotTestAttestation
        #Set-Executionpolicy Bypass -Scope Process
        Import-Module AutopilotTestAttestation
        Test-AutopilotAttestation
        }
    4{# Clear TPM
        Write-Host 
        Write-Host " = Clear the TPM = " -ForegroundColor Magenta
        Write-Host
        Write-Host "* You will lose access to encrypted data unless you have the BitLocker recovery key." -ForegroundColor Red
        Write-Host "* You will need to wipe and re-enroll the machine in MDM/Autopilot." -ForegroundColor Red
        Write-Host "* Users can be locked out if they rely on TPM-based login or encryption." -ForegroundColor Red
        Write-Host
        Confirm-ContinueN
        Confirm-ContinueN -Message "Are you sure?"
        Write-Host
        #Clear-TPM
    }
    default {#Exit Command
        Exit 
    }
}

