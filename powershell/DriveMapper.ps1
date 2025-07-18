# Version 1.00 (7/14/2025)
# * Initial Release
# Version 1.10 (7/14/2025)
# * Added Dropdown to select from available backups
# Version 1.20 (7/18/2025)
# * Cleaned up GUI
# * Default backup locations are Script Directory and current user desktop
# * Added Dropdown to select from defined backup locations
# * "Available Backups" also searches all defined backup locations
#
# Vincent Macaluso (R3)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:cancelled = $true

$serial = (Get-CimInstance Win32_BIOS).SerialNumber
$backupDir = "DriveMapper"
$backupFile = Join-Path $backupDir "$serial.txt"

$backupLocations = @(
    @{ Name = "<User Desktop>"; Path = Join-Path -Path ([Environment]::GetFolderPath("Desktop")) -ChildPath $backupDir },
    @{ Name = "<Script Dir  >"; Path = Join-Path -Path (Get-Location).Path -ChildPath $backupDir }
)

if (-not (Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$drives = @(
    @{ Letter = "A:"; Name = "Pictures"; Path = "\\drive01.network.int\Pictures" },
    @{ Letter = "B:"; Name = "Warez"; Path = "\\1.2.3.4.5\Warez" }
)

# Section Heights
$mainFormWindowWidth = 670
$buttonHeight = 25
$labelHeight = 20
$sectionPadding = 20
$sectionColumnContentWidth = ($mainFormWindowWidth / 2) - ($sectionPadding * 2)
$sectionColumnOneX = $sectionPadding
$sectionColumnTwoX = $sectionColumnContentWidth + $sectionPadding + $sectionPadding

# Drive Selection Table Label
$driveListViewHeight = ($drives.Count - 1) * 21
$driveListSectionY = $sectionPadding

$SelectAllToggleY = $driveListSectionY

$driveListViewLabelY = $SelectAllToggleY + $buttonHeight + $sectionPadding
$driveListViewY = $driveListViewLabelY + $labelHeight 

$applyChangesButtonX = $sectionColumnOneX
$applyChangesButtonY = $driveListViewY + $driveListViewHeight + $sectionPadding
$applyChangesButtonWidth = $mainFormWindowWidth - ($sectionPadding * 3)

$driveListViewSectionTotalHeight = $applyChangesButtonY + $buttonHeight

# Select Backup File Section

# Column One
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
$quitButtonY = $backupFileInfoLabelY + $buttonHeight + $sectionPadding

$mainFormWindowHeight = $quitButtonY + ($buttonHeight * 2) + ($sectionPadding * 2) 

Write-Host "Main Height: $quitButtonY $mainFormWindowHeight" -ForegroundColor White
# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Drive Mapper"
$form.Size = New-Object System.Drawing.Size($mainFormWindowWidth,$mainFormWindowHeight)
$form.StartPosition = "CenterScreen"

function Update-BackupDir {
        $selectedDir = $global:backupDirMap[$backupDirSelector.SelectedItem]

        $backupDir = $selectedDir['Path']
        $backupDirName = $selectedDir['Name']

        $backupFile = Join-Path $backupDir "$serial.txt"

    if (Test-Path $backupFile) {
        $info = Get-Item $backupFile
        $backupInfo.Text = "This device's backup: $($info.Name) (Last modified: $($info.LastWriteTime))"
    } else {
        $backupInfo.Text = "No backup file found for this device."
    }
}

# Initial call to set backup directory
#Update-BackupDir


# Toggle Select/Deselect All Button
$SelectAllToggle = New-Object System.Windows.Forms.Button
$SelectAllToggle.Text = "Select/Deselect All"
$SelectAllToggle.Location = New-Object System.Drawing.Point(20,$SelectAllToggleY)
$SelectAllToggle.Size = New-Object System.Drawing.Size(150,25)
$SelectAllToggle.Add_Click({
    $accessibleItems = $driveListView.Items | Where-Object { $_.SubItems[3].Text -ne "No Access" }
    $allChecked = $accessibleItems | Where-Object { -not $_.Checked } | Measure-Object | Select-Object -ExpandProperty Count
    $newState = ($allChecked -gt 0)
    foreach ($item in $accessibleItems) {
        $item.Checked = $newState
    }
})
$form.Controls.Add($SelectAllToggle)

# Backup File Selector
$backupFileSelectorLabel = New-Object System.Windows.Forms.Label
$backupFileSelectorLabel.Text = "Select a backup file to restore from:"
$backupFileSelectorLabel.Size = New-Object System.Drawing.Size($sectionColumnContentWidth,20)
$backupFileSelectorLabel.Location = New-Object System.Drawing.Point($selectRestoreFileLabelX,$selectRestoreFileLabelY)
$form.Controls.Add($backupFileSelectorLabel)

$backupFileSelector = New-Object System.Windows.Forms.ComboBox
$backupFileSelector.Location = New-Object System.Drawing.Point($selectRestoreFileX,$selectRestoreFileY)
$backupFileSelector.Size = New-Object System.Drawing.Size($sectionColumnContentWidth, 25)
$backupFileSelector.DropDownStyle = 'DropDownList'


$backupFileSelector.Items.Clear()
$global:backupFileMap = @{}
foreach ($location in $backupLocations) {
        Get-ChildItem -Path $location.Path -Filter *.txt | ForEach-Object {
        $display = "$($location.Name): $($_.Name)"
        $backupFileSelector.Items.Add($display)
        $global:backupFileMap[$display] = $_.FullName
    }
}



if ($backupFileSelector.Count -gt 0) {
    $backupFileSelector.SelectedIndex = 0
}
$form.Controls.Add($backupFileSelector)

# Backup File Selector
$backupDirSelectorLabel = New-Object System.Windows.Forms.Label
$backupDirSelectorLabel.Text = "Select a backup directoy:"
$backupDirSelectorLabel.Location = New-Object System.Drawing.Point($selectBackupDirLabelX, $selectBackupDirLabelY)
$backupDirSelectorLabel.Size = New-Object System.Drawing.Size($selectBackupDirLabelWidth,20)
$form.Controls.Add($backupDirSelectorLabel)

$backupDirSelector = New-Object System.Windows.Forms.ComboBox
$backupDirSelector.Location = New-Object System.Drawing.Point($selectBackupDirX, $selectBackupDirY)
$backupDirSelector.Size = New-Object System.Drawing.Size($selectBackupDirWidth, 25)
$backupDirSelector.DropDownStyle = 'DropDownList'


$backupDirSelector.Items.Clear()

$global:backupDirMap = @{}
foreach ($location in $backupLocations) {
    $display = "$($location.Name)"
    $backupDirSelector.Items.Add($display)

    $global:backupDirMap[$display] = @{
        Name = $location.Name
        Path = $location.Path
    }
}



if ($backupDirSelector.Count -gt 0) {
    $backupDirSelector.SelectedIndex = 0
}
$form.Controls.Add($backupDirSelector)


$backupDirSelector.Add_SelectedIndexChanged({
        $selectedDir = $global:backupDirMap[$backupDirSelector.SelectedItem]

        $backupDir = $selectedDir['Path']
        $backupDirName = $selectedDir['Name']

        $backupFile = Join-Path $backupDir "$serial.txt"

        Write-Host "Selected Name: $backupDirName" -ForegroundColor Yellow
        Write-Host "Selected Path: $backupDir" -ForegroundColor Yellow
        

        Write-Host "Backup directory set to: $backupDir" -ForegroundColor Cyan
        Write-Host "Backup file path set to: $backupFile" -ForegroundColor Magenta
 })

 $backupFileSelector.Add_SelectedIndexChanged({
    #Update-BackupDir
 })

Write-Host "Backup directory set to: $backupDir" -ForegroundColor Cyan
Write-Host "Backup file path set to: $backupFile" -ForegroundColor Magenta

# Instructions
$driveListViewLabel = New-Object System.Windows.Forms.Label
$driveListViewLabel.Text = "Select the drives to MAP or KEEP mapped. All others will be removed:"
$driveListViewLabel.Size = New-Object System.Drawing.Size(600,20)
$driveListViewLabel.Location = New-Object System.Drawing.Point($sectionPadding,$driveListViewLabelY)
$form.Controls.Add($driveListViewLabel)

# Info about current serial's backup
$backupFileInfo = New-Object System.Windows.Forms.Label
$backupFileInfo.Size = New-Object System.Drawing.Size($backupFileInfoLabelWidth,$backupFileInfoLabelHeight)
$backupFileInfo.Location = New-Object System.Drawing.Point($backupFileInfoLabelX,$backupFileInfoLabelY)
if (Test-Path $backupFile) {
    $info = Get-Item $backupFile
    $backupFileInfo.Text = "Selected backup: $($info.Name) `nLast modified: $($info.LastWriteTime)"
} else {
    $backupInfo.Text = "No backup file found for this device."
}
$form.Controls.Add($backupFileInfo)

# driveListView
$driveListView = New-Object System.Windows.Forms.ListView
$driveListView.Size = New-Object System.Drawing.Size(620,$driveListViewHeight)
$driveListView.Location = New-Object System.Drawing.Point(20,$driveListViewY)
$driveListView.View = 'Details'
$driveListView.CheckBoxes = $true
$driveListView.FullRowSelect = $true
$driveListView.GridLines = $true
$driveListView.Columns.Add("Letter", 50)
$driveListView.Columns.Add("Name", 120)
$driveListView.Columns.Add("Path", 300)
$driveListView.Columns.Add("Current Status", 100)
$form.Controls.Add($driveListView)

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
    $item.SubItems.Add($drive.Name)
    $item.SubItems.Add($path)
    $item.SubItems.Add($status)
    $item.Tag = $drive
    if ($mapped) { $item.Checked = $true }
    if ($status -eq "No Access") { $item.ForeColor = [System.Drawing.Color]::Gray }
    if ($status -eq "Mapped") { $item.ForeColor = [System.Drawing.Color]::Green }
    $driveListView.Items.Add($item)
}

# Buttons
$applyChangesButton = New-Object System.Windows.Forms.Button
$applyChangesButton.Text = "Apply Changes"
$applyChangesButton.Location = New-Object System.Drawing.Point($applyChangesButtonX,$applyChangesButtonY)
$applyChangesButton.Size = New-Object System.Drawing.Size($applyChangesButtonWidth, 25)
$applyChangesButton.Add_Click({
    $global:cancelled = $false
    $form.Close()
})
$form.Controls.Add($applyChangesButton)

$backupToDirButton = New-Object System.Windows.Forms.Button
$backupToDirButton.Text = "Backup"
$backupToDirButton.Location = New-Object System.Drawing.Point($backupToDirButtonX,$backupToDirButtonY)
$backupToDirButton.Size = New-Object System.Drawing.Size($backupToDirButtonWidth,25)

$backupToDirButton.Add_Click({
        $selectedDir = $global:backupDirMap[$backupDirSelector.SelectedItem]
        $backupDir = $selectedDir['Path']
        $backupDirName = $selectedDir['Name']
        $backupFile = Join-Path $backupDir "$serial.txt"

        $currentMappings = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" } |
        ForEach-Object { "$($_.Name): $($_.DisplayRoot)" }
        $currentMappings | Set-Content -Path $backupFile
    [System.Windows.Forms.MessageBox]::Show("Drive mappings backed up to $backupDirName")
})
$form.Controls.Add($backupToDirButton)


$restoreFromBackupFileButton = New-Object System.Windows.Forms.Button
$restoreFromBackupFileButton.Text = "Restore Selected"
$restoreFromBackupFileButton.Location = New-Object System.Drawing.Point($restoreFromBackupFileButtonX,$restoreFromBackupFileButtonY)
$restoreFromBackupFileButton.Size = New-Object System.Drawing.Size($restoreFromBackupFileButtonWidth,25)
$restoreFromBackupFileButton.Add_Click({
    if ($backupFileSelector.SelectedItem) {
         
        $selectedFile = $global:backupFileMap[$backupFileSelector.SelectedItem]

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
            [System.Windows.Forms.MessageBox]::Show("Drive selections updated from backup file: $($backupFileSelector.SelectedItem)")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Selected backup file not found.")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a backup file from the dropdown list.")
    }
})
$form.Controls.Add($restoreFromBackupFileButton)


$quitButton = New-Object System.Windows.Forms.Button
$quitButton.Text = "Quit"
$quitButton.Location = New-Object System.Drawing.Point($quitButtonX,$quitButtonY)
$quitButton.Size = New-Object System.Drawing.Size($quitButtonWidth,25)
$quitButton.Add_Click({
    $global:cancelled = $true
    $form.Close()
})
$form.Controls.Add($quitButton)

$form.add_FormClosing({
    if ($form.DialogResult -ne [System.Windows.Forms.DialogResult]::OK -and $global:cancelled -ne $false) {
        $global:cancelled = $true
    }
})


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
