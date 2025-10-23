# Vincent Macaluso

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:cancelled = $true

$currentVer = 1.5
$serial = (Get-CimInstance Win32_BIOS).SerialNumber
$username = $env:username
$backupDirName = "DriveMapper"
$backupFileName = $($username + '_' + $serial) + ".txt"
$scriptDir = $PSScriptRoot
$desktopDir = ([Environment]::GetFolderPath("Desktop"))
$backupDir = Join-Path -Path $desktopDir -ChildPath $backupDirName
$backupFile = Join-Path -Path $backupDir $backupFileName

Write-Host " =  Drive Mapper $currentVer  = " -ForegroundColor white -BackgroundColor DarkMagenta
Write-Host
Write-Host "Current User    : $username" -ForegroundColor white
Write-Host


$backupLocations = @(
    @{ Name = "<User Desktop> - Recommended"; Path = Join-Path -Path $desktopDir -ChildPath $backupDirName },
    @{ Name = "<Script Dir  > Needs Write Permission On Drive."; Path = Join-Path -Path $scriptDir -ChildPath $backupDirName }
)

$drives = @(
    @{ Letter = "D:"; Name = "D Drive"; Path = "\\server1\path" },
    @{ Letter = "E:"; Name = "E Drive"; Path = "\\server2\path" }
)

#Asset Heights / Widths
$mainFormWindowWidth = 670
$sectionPadding = 20
$mainFormWindowContentWidth = $mainFormWindowWidth - ($sectionPadding * 3)
$buttonHeight = 25
$labelHeight = 20


# Section Collumn X/ Y / Heights / Widths
$sectionColumnContentWidth = ($mainFormWindowWidth / 2) - ($sectionPadding * 2)
$sectionColumnOneX = $sectionPadding
$sectionColumnOneY = $sectionPadding
$sectionColumnTwoX = $sectionColumnContentWidth + $sectionPadding + $sectionPadding

# Select All/None Toggle
$SelectAllToggleX = $sectionColumnOneX
$SelectAllToggleY = $sectionColumnOneY
$SelectAllToggleWidth = $sectionColumnContentWidth

# Drive Selection ListView / Table
$driveListViewLabelY = $sectionColumnOneX
$driveListViewLabelY = $SelectAllToggleY + $buttonHeight + $sectionPadding
$driveListViewX = $sectionColumnOneX
$driveListViewY = $driveListViewLabelY + $labelHeight 
$driveListViewHeight = ($drives.Count) * 22
$driveListViewWidth = $mainFormWindowContentWidth

$applyChangesButtonX = $sectionColumnOneX
$applyChangesButtonY = $driveListViewY + $driveListViewHeight + $sectionPadding
$applyChangesButtonWidth = $mainFormWindowContentWidth



#Write-Host "Main Height: $quitButtonY $mainFormWindowHeight" -ForegroundColor White
# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Drive Mapper"
$form.StartPosition = "CenterScreen"

function Set-ListViewHeight {
    param($lv)
    $itemHeight = $lv.Items[0].Bounds.Height # Get height of a single item
    $totalHeight = $itemHeight * $lv.Items.Count
    $lv.Height = $totalHeight + 30 # Add a small buffer for header/borders
}


# Building form Elements

# Toggle Select/Deselect All Button
$SelectAllToggle = New-Object System.Windows.Forms.Button
$SelectAllToggle.Text = "Select/Deselect All"
$SelectAllToggle.Location = New-Object System.Drawing.Point($SelectAllToggleX,$SelectAllToggleY)
$SelectAllToggle.Size = New-Object System.Drawing.Size($SelectAllToggleWidth,$buttonHeight)
$SelectAllToggle.Add_Click({
    $accessibleItems = $driveListView.Items | Where-Object { $_.SubItems[3].Text -ne "No Access" }
    $allChecked = $accessibleItems | Where-Object { -not $_.Checked } | Measure-Object | Select-Object -ExpandProperty Count
    $newState = ($allChecked -gt 0)
    foreach ($item in $accessibleItems) {
        $item.Checked = $newState
    }
})
[void]$form.Controls.Add($SelectAllToggle)

# Instructions
$driveListViewLabel = New-Object System.Windows.Forms.Label
$driveListViewLabel.Text = "Select the drives to MAP or KEEP mapped. All others will be removed:"
$driveListViewLabel.Size = New-Object System.Drawing.Size($mainFormWindowContentWidth,$labelHeight)
$driveListViewLabel.Location = New-Object System.Drawing.Point($sectionPadding,$driveListViewLabelY)
[void]$form.Controls.Add($driveListViewLabel)

# driveListView
$driveListView = New-Object System.Windows.Forms.ListView
$driveListView.Size = New-Object System.Drawing.Size($driveListViewWidth,$driveListViewHeight)
$driveListView.Location = New-Object System.Drawing.Point($driveListViewX,$driveListViewY)
$driveListView.View = 'Details'
$driveListView.CheckBoxes = $true
$driveListView.FullRowSelect = $true
$driveListView.GridLines = $true
[Void]$driveListView.Columns.Add("Letter", 50)
[Void]$driveListView.Columns.Add("Name", 120)
[Void]$driveListView.Columns.Add("Path", 300)
[Void]$driveListView.Columns.Add("Current Status", 100)
[void]$form.Controls.Add($driveListView)

$driveListView.add_ItemCheck({
    param($sender, $e)
    $currentItem = $driveListView.Items[$e.Index]
    $currentDrive = $currentItem.Tag
    if ($currentItem.SubItems[3].Text -eq "No Access") {
        $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
        return
    }
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        foreach ($i in 0..($driveListView.Items.Count - 1)) {
            if ($i -ne $e.Index) {
                $otherItem = $driveListView.Items[$i]
                $otherDrive = $otherItem.Tag
                if ($otherDrive.Letter -eq $currentDrive.Letter) {
                    $otherItem.Checked = $false
                }
            }
        }
    }
})

foreach ($drive in $drives) {
    $letter = $drive.Letter
    $path = $drive.Path
    $mapped = Test-Path "$letter\"
    $accessible = $false
    try {
        $null = Get-ChildItem -Path $path -ErrorAction Stop
        $accessible = $true
    } catch {
        $accessible = $false
    }
    $status = if ($mapped) { "Mapped" } elseif ($accessible) { "Available" } else { "No Access" }

    $item = New-Object System.Windows.Forms.ListViewItem($letter)
    [Void]$item.SubItems.Add($drive.Name)
    [Void]$item.SubItems.Add($path)
    [Void]$item.SubItems.Add($status)
    $item.Tag = $drive
    if ($mapped) { $item.Checked = $true }
    if ($status -eq "No Access") { $item.ForeColor = [System.Drawing.Color]::Gray }
    if ($status -eq "Mapped") { $item.ForeColor = [System.Drawing.Color]::Green }
    [Void]$driveListView.Items.Add($item)
    Set-ListViewHeight $driveListView
    $applyChangesButtonY = $driveListViewY + $driveListView.Height + $sectionPadding
}

# Apply Changes Button
$applyChangesButton = New-Object System.Windows.Forms.Button
$applyChangesButton.Text = "Apply Changes"
$applyChangesButton.Location = New-Object System.Drawing.Point($applyChangesButtonX,$applyChangesButtonY)
$applyChangesButton.Size = New-Object System.Drawing.Size($applyChangesButtonWidth, $buttonHeight)
$applyChangesButton.Add_Click({
    $global:cancelled = $false
    $form.Close()
})
[void]$form.Controls.Add($applyChangesButton)



$driveListViewSectionTotalHeight = $applyChangesButtonY + $buttonHeight

# Select Backup File Section
$selectBackupSectionY = $driveListViewSectionTotalHeight + $sectionPadding

$selectBackupDirLabelX = $sectionColumnOneX
$selectBackupDirLabelY = $selectBackupSectionY
$selectBackupDirLabelWidth = $sectionColumnContentWidth

$selectBackupDirX = $sectionColumnOneX
$selectBackupDirY = $selectBackupDirLabelY  + $labelHeight
$selectBackupDirWidth = $sectionColumnContentWidth

$backupToDirButtonX = $sectionColumnOneX
$backupToDirButtonY = $selectBackupDirY + $labelHeight + $sectionPadding
$backupToDirButtonWidth = $sectionColumnContentWidth

#ColumnTwo
$selectRestoreFileLabelX = $sectionColumnTwoX
$selectRestoreFileLabelY = $selectBackupSectionY

$selectRestoreFileX = $sectionColumnTwoX
$selectRestoreFileY = $selectRestoreFileLabelY + $labelHeight
$selectRestoreFileWidth = $sectionColumnContentWidth

$restoreFromBackupFileButtonX = $sectionColumnTwoX
$restoreFromBackupFileButtonY = $selectBackupDirY + $labelHeight + $sectionPadding
$restoreFromBackupFileButtonWidth = $sectionColumnContentWidth

$backupFileInfoLabelX = $sectionColumnTwoX
$backupFileInfoLabelY = $restoreFromBackupFileButtonY + $buttonHeight + 10
$backupFileInfoLabelWidth = $sectionColumnContentWidth
$backupFileInfoLabelHeight = 40

$quitButtonWidth = $sectionColumnContentWidth
$quitButtonX = ($mainFormWindowWidth / 2) - ($quitButtonWidth / 2)
$quitButtonY = $backupFileInfoLabelY + $buttonHeight + ($sectionPadding * 2)

$mainFormWindowHeight = $quitButtonY + ($buttonHeight * 2) + ($sectionPadding * 2) 






# Select Restore File Selector
$selectRestoreFileLabel = New-Object System.Windows.Forms.Label
$selectRestoreFileLabel.Text = "Select a backup file to restore from:"
$selectRestoreFileLabel.Size = New-Object System.Drawing.Size($sectionColumnContentWidth,$labelHeight)
$selectRestoreFileLabel.Location = New-Object System.Drawing.Point($selectRestoreFileLabelX,$selectRestoreFileLabelY)
[void]$form.Controls.Add($selectRestoreFileLabel)

$selectRestoreFile = New-Object System.Windows.Forms.ComboBox
$selectRestoreFile.Location = New-Object System.Drawing.Point($selectRestoreFileX,$selectRestoreFileY)
$selectRestoreFile.Size = New-Object System.Drawing.Size($selectRestoreFileWidth, $buttonHeight)
$selectRestoreFile.DropDownStyle = 'DropDownList'

$selectRestoreFile.Items.Clear()
$global:backupFileMap = @{}
foreach ($location in $backupLocations) {
        Get-ChildItem -Path $location.Path -Filter *.txt | ForEach-Object {
        $display = "$($location.Name): $($_.Name)"
        [Void]$selectRestoreFile.Items.Add($display)
        $global:backupFileMap[$display] = $_.FullName
    }
}

if ($selectRestoreFile.Count -gt 0) {
    $selectRestoreFile.SelectedIndex = 0
}
[void]$form.Controls.Add($selectRestoreFile)

# Backup File Selector
$backupDirSelectorLabel = New-Object System.Windows.Forms.Label
$backupDirSelectorLabel.Text = "Select a backup directoy:"
$backupDirSelectorLabel.Location = New-Object System.Drawing.Point($selectBackupDirLabelX, $selectBackupDirLabelY)
$backupDirSelectorLabel.Size = New-Object System.Drawing.Size($selectBackupDirLabelWidth,$labelHeight)
[void]$form.Controls.Add($backupDirSelectorLabel)

$backupDirSelector = New-Object System.Windows.Forms.ComboBox
$backupDirSelector.Location = New-Object System.Drawing.Point($selectBackupDirX, $selectBackupDirY)
$backupDirSelector.Size = New-Object System.Drawing.Size($selectBackupDirWidth, $buttonHeight)
$backupDirSelector.DropDownStyle = 'DropDownList'

$backupDirSelector.Items.Clear()

$global:backupDirMap = @{}
foreach ($location in $backupLocations) {
    $display = "$($location.Name)"
    [Void]$backupDirSelector.Items.Add($display)

    $global:backupDirMap[$display] = @{
        Name = $location.Name
        Path = $location.Path
    }
}

if ($backupDirSelector.Count -gt 0) {
    $backupDirSelector.SelectedIndex = 0
}
[void]$form.Controls.Add($backupDirSelector)


$backupDirSelector.Add_SelectedIndexChanged({
        $selectedDir = $global:backupDirMap[$backupDirSelector.SelectedItem]

        $backupDir = $selectedDir['Path']
        $backupDirName = $selectedDir['Name']

        $backupFile = Join-Path $backupDir $backupFileName

        Write-Host "Selected Name: $backupDirName" -ForegroundColor Yellow
        Write-Host "Selected Path: $backupDir" -ForegroundColor Yellow
 
        Write-Host "Backup directory set to: $backupDir" -ForegroundColor Cyan
        Write-Host "Backup file path set to: $backupFile" -ForegroundColor Magenta
 })

 $selectRestoreFile.Add_SelectedIndexChanged({
    $selectedFile = $global:backupFileMap[$selectRestoreFile.SelectedItem]
    $backupFile = $selectedFile
    Update-backupFileInfo $backupFile

 })

$selectedFile = $global:backupFileMap[$selectRestoreFile.SelectedItem]
Write-Host "Selected file: $selectedFile" -ForegroundColor Cyan
Write-Host "Backup directory set to: $backupDir" -ForegroundColor Cyan
Write-Host "Backup file path set to: $backupFile" -ForegroundColor Magenta

# Info about current serial's backup
$backupFileInfo = New-Object System.Windows.Forms.Label
$backupFileInfo.Size = New-Object System.Drawing.Size($backupFileInfoLabelWidth,$backupFileInfoLabelHeight)
$backupFileInfo.Location = New-Object System.Drawing.Point($backupFileInfoLabelX,$backupFileInfoLabelY)
Write-Host $backupFile -ForegroundColor Red
if (Test-Path $backupFile) {
    $info = Get-Item $backupFile
    $backupFileInfo.Text = "Selected backup: $($info.Name) `nLast modified: $($info.LastWriteTime)"
} else {
    $backupFileInfo.Text = "No backup file found for this device."
}
[void]$form.Controls.Add($backupFileInfo)

# Info about current serial's backup
function Update-backupFileInfo {

    param($backupFile)
    Write-Host $backupFile -ForegroundColor Cyan


if (Test-Path $backupFile) {
    $info = Get-Item $backupFile
     $backupFileInfo.Text = "Selected backup: $($info.Name) `nLast modified: $($info.LastWriteTime)"
     Write-Host "Selected backup: $($info.Name) `nLast modified: $($info.LastWriteTime)"
} else {
    $backupFileInfo.Text = "No backup file found for this device."
    [void]$form.Controls.Add($backupFileInfo)
}
}
Update-backupFileInfo $selectedFile

$backupToDirButton = New-Object System.Windows.Forms.Button
$backupToDirButton.Text = "Backup"
$backupToDirButton.Location = New-Object System.Drawing.Point($backupToDirButtonX,$backupToDirButtonY)
$backupToDirButton.Size = New-Object System.Drawing.Size($backupToDirButtonWidth,$buttonHeight)

$backupToDirButton.Add_Click({
        $selectedDir = $global:backupDirMap[$backupDirSelector.SelectedItem]
        $backupDir = $selectedDir['Path']
        $backupDirName = $selectedDir['Name']
        $backupFile = Join-Path $backupDir $backupFileName

        $currentMappings = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" } |
        ForEach-Object { "$($_.Name): $($_.DisplayRoot)" }
        $currentMappings | Set-Content -Path $backupFile
    [System.Windows.Forms.MessageBox]::Show("Drive mappings backed up to $backupDirName")
})
[void]$form.Controls.Add($backupToDirButton)

$restoreFromBackupFileButton = New-Object System.Windows.Forms.Button
$restoreFromBackupFileButton.Text = "Restore Selected"
$restoreFromBackupFileButton.Location = New-Object System.Drawing.Point($restoreFromBackupFileButtonX,$restoreFromBackupFileButtonY)
$restoreFromBackupFileButton.Size = New-Object System.Drawing.Size($restoreFromBackupFileButtonWidth,$buttonHeight)
$restoreFromBackupFileButton.Add_Click({
    if ($selectRestoreFile.SelectedItem) {
         
        $selectedFile = $global:backupFileMap[$selectRestoreFile.SelectedItem]

        if (Test-Path $selectedFile) {
            $lines = Get-Content $selectedFile
            $lettersToRestore = @{}
            foreach ($line in $lines) {
                if ($line -match "^(\w):\s+(\\\\.+)$") {
                    $lettersToRestore["$($matches[1]):"] = $matches[2]
                }
            }
            foreach ($item in $driveListView.Items) {
                $drive = $item.Tag
                if ($lettersToRestore.ContainsKey($drive.Letter) -and $lettersToRestore[$drive.Letter] -eq $drive.Path -and $item.SubItems[3].Text -ne "No Access") {
                    $item.Checked = $true
                } else {
                    $item.Checked = $false
                }
            }
            #[System.Windows.Forms.MessageBox]::Show("Drive selections updated from backup file: $($selectRestoreFile.SelectedItem)")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Selected backup file not found.")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a backup file from the dropdown list.")
    }
})
[void]$form.Controls.Add($restoreFromBackupFileButton)


$quitButton = New-Object System.Windows.Forms.Button
$quitButton.Text = "Quit"
$quitButton.Location = New-Object System.Drawing.Point($quitButtonX,$quitButtonY)
$quitButton.Size = New-Object System.Drawing.Size($quitButtonWidth,$buttonHeight)
$quitButton.Add_Click({
    $global:cancelled = $true
    $form.Close()
})
[void]$form.Controls.Add($quitButton)

$form.add_FormClosing({
    if ($form.DialogResult -ne [System.Windows.Forms.DialogResult]::OK -and $global:cancelled -ne $false) {
        $global:cancelled = $true
    }
})

$form.Size = New-Object System.Drawing.Size($mainFormWindowWidth,$mainFormWindowHeight)
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })

[void]$form.ShowDialog() 

# Process selected drives
if (-not $global:cancelled) {
    $selectedDrives = $driveListView.CheckedItems | ForEach-Object { $_.Tag }

    foreach ($drive in $selectedDrives) {
        $letter = $drive.Letter
        $path = $drive.Path
        Write-Host "`nMapping $letter to $path..."
        if (Test-Path "$letter\") {
            net use $letter /delete /yes 2>&1 | Out-Null
        }
        $output = net use $letter $path /persistent:yes 2>&1
        if ($LASTEXITCODE -ne 0) {
            [System.Windows.Forms.MessageBox]::Show("Failed to map $letter to $path `n$output")
        } else {
            Write-Host "Mapped $letter"
        }
    }

    $uncheckedDrives = $drives | Where-Object { $selectedDrives -notcontains $_ }
    foreach ($drive in $uncheckedDrives) {
        $letter = $drive.Letter
        if (Test-Path "$letter\") {
            Write-Host "`nRemoving mapping for $letter..."
            net use $letter /delete /yes 2>&1 | Out-Null
            Write-Host "$letter unmapped."
        }
    }
}
