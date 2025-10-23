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
switch ($choice.KeyChar){
    1{# Upgrade Windows (Via Powershell)
        Write-Host
        Write-Host "You may see an error or two - you may ignore these as long as it works. :)" -ForegroundColor Cyan
        Write-Host
        Start-Sleep -Seconds 2

        Install-PackageProvider -Name Nuget -minimumVersion 2.8.5.201 -Force
        Install-Module -Name PowerShellGet -Force -AllowClobber
        Import-Module PowerShellGet
        SetPSRepository -Name “PSGallery” -InstallationPolicy Trusted
        Install-Module PSWindowsUpdate -AllowClobber -Force
        Get-windowsupdate -Microsoftupdate -acceptall -install -ignorereboot
        }
        
    2{# Upgrade Windows (via Windows Check For Updates)
        Write-Host
        Write-Host "Trying to open the Windows Control Panel... If you don't see it, it didn't work." -ForegroundColor White
        Write-Host
        Start-Sleep -Seconds 2
        control update
        }
    3{# Run Autopilot Test Attestation
        Install-Module AutopilotTestAttestation
        Set-Executionpolicy Bypass -Scope Process
        Import-Module AutopilotTestAttestation
        Test-AutopilotAttestation
        }
    4{# Clear TPM
        Clear-TPM
    }
    default {#Exit Command
        Exit 
    }
}

