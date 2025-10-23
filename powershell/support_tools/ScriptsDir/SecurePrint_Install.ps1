$printServer = ""
$printerName = ""
$printerPath = "\\$printServer\$printerName"
$scriptTitle = " = $printerName Printer Install ** Requires In-Office, Non-VPN Network Connection = "
$textTesting = "Testing Connectivity To $printerPath ..."
$textPass = " Test Passed.".PadRight($textTesting.Length,' ')
$textFail = " Test Failed.".PadRight($textTesting.Length,' ')
$textTryAgain = " Try again just in case there was a glitch"
$textNetwork = " Device must be on the office network, does not work via Azure VPN.".PadRight($textTesting.Length,' ')
$textIsInstalled = "Checking to see if $printerName is already installed ..."
$textPrompt = " Would you like to Re/Install $printerName from ${printServer}? "
$textYN = "[Y/N]"
$printerInstalled = 0

Clear-Host
Write-Host $scriptTitle -ForegroundColor White -BackgroundColor Magenta
Write-Host
Write-Host $textTesting -ForegroundColor White

if (Test-Connection $printServer -Count 2 -Quiet) {
    $printersMapped = Get-Printer
    Start-Sleep -Seconds 1
    Write-Host $textPass -ForegroundColor Green
    Write-Host
    
    ## Checking if SecurePrint is already installed.
    Write-Host $textIsInstalled -ForegroundColor White
    foreach ($printer in $printersMapped) {
         Start-Sleep -Milliseconds 500
         # Check if the printer's Name property contains Printername (case-insensitive)

        if ($printer.Name -like "*$printerName*") {
            # API_SecurePrint
            $printerInstalled = 1
            Write-Host " Found ${printerName}: $($printer.Name)" -ForegroundColor Green
            
        } else {
            Write-Host " Found $($printer.Name)" -ForegroundColor Gray
        }
    }

    Write-Host
    Write-Host $textPrompt -ForegroundColor Magenta -NoNewline
    Write-Host $textYN -ForegroundColor White -BackgroundColor Magenta -NoNewline
    $answer = Read-Host " " 
    $answer = $answer.ToLower()
   if ($answer -eq 'y') {
    if ($printerInstalled = 1) {
        Write-Host
        Write-Host "$printerName is being removed." -ForegroundColor White
        Remove-Printer -Name $printerPath
        Write-Host " And like the phoenix from the flame, it shall return." -ForegroundColor Red
    }
    Write-Host
    Write-Host "$printerName is being added." -ForegroundColor White
    Add-Printer -ConnectionName $printerPath
    Write-Host " $printerName has been added." -ForegroundColor Green
    Write-Host
    } else {
        Write-Host
        Write-Host "No changes have been made." -ForegroundColor Cyan
        Write-Host
    }

    } else { 
        Write-Host $textFail -ForegroundColor Red
        Write-Host
        Write-Host $textNetwork -ForegroundColor Cyan
        Write-Host $textTryAgain -ForegroundColor Gray
        Write-Host
        }
    
    Write-Host ":: " -ForegroundColor Cyan -NoNewline
    Write-Host "Press ENTER Key To Exit" -ForegroundColor Magenta -NoNewline
    Write-Host " ::"-ForegroundColor Cyan -NoNewline
    Read-Host 