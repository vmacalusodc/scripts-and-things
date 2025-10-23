$options = ' = ',' ** ',' # ',' ## ',' - ',' % ',' <> ',' >< ',' O ',' -O- '
$bullets = Get-Random -InputObject $options

$colors = "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White"
$randomcolors = $colors | Get-Random -Count 2
$color1, $color2 = $randomcolors

$prompts = "Press ENTER To Quit", "Smash That ENTER Key", "[ENTER] To Quit"
$prompt = Get-Random -InputObject $prompts
function Show-Pause {
    Write-Host
    Write-Host $bullets -ForegroundColor $color1 -NoNewline
    Write-Host $prompt -ForegroundColor $color2 -NoNewline
    Write-Host $bullets -ForegroundColor $color1 -NoNewline
    Read-Host | Out-Null
}