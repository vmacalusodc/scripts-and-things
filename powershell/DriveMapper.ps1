# Version 1.00 (7/14/2025)
# * Initial Release
# * Display all configured network drives
# * Present user with list of all drives and indicate which are available
# * Backup and restore
# Version 1.10 (7/14/2025)
# * Added Dropdown to select from available backups.
#
# Vincent Macaluso (R3)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:cancelled = $true

$serial = (Get-CimInstance Win32_BIOS).SerialNumber
$backupDir = Join-Path -Path (Get-Location).Path -ChildPath "DriveMapper"

if (-not (Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$backupFile = Join-Path $backupDir "$serial.txt"

$drives = @(
    @{ Letter = "A:"; Name = "Pictures"; Path = "\\drive01.network.int\Pictures" },
    @{ Letter = "B:"; Name = "Warez"; Path = "\\1.2.3.4.5\Warez" }
)

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Shared Drive Mapper"
$form.Size = New-Object System.Drawing.Size(670,720)
$form.StartPosition = "CenterScreen"

# Toggle Select/Deselect All Button
$toggleButton = New-Object System.Windows.Forms.Button
$toggleButton.Text = "Select/Deselect All"
$toggleButton.Location = New-Object System.Drawing.Point(20,10)
$toggleButton.Size = New-Object System.Drawing.Size(150,25)
$toggleButton.Add_Click({
    $accessibleItems = $listView.Items | Where-Object { $_.SubItems[3].Text -ne "No Access" }
    $allChecked = $accessibleItems | Where-Object { -not $_.Checked } | Measure-Object | Select-Object -ExpandProperty Count
    $newState = ($allChecked -gt 0)
    foreach ($item in $accessibleItems) {
        $item.Checked = $newState
    }
})
$form.Controls.Add($toggleButton)

# Backup File Selector
$backupSelectorLabel = New-Object System.Windows.Forms.Label
$backupSelectorLabel.Text = "Select a backup file to restore from:"
$backupSelectorLabel.Size = New-Object System.Drawing.Size(250,20)
$backupSelectorLabel.Location = New-Object System.Drawing.Point(300,10)
$form.Controls.Add($backupSelectorLabel)

$backupSelector = New-Object System.Windows.Forms.ComboBox
$backupSelector.Location = New-Object System.Drawing.Point(300,30)
$backupSelector.Size = New-Object System.Drawing.Size(300, 25)
$backupSelector.DropDownStyle = 'DropDownList'
$backupFiles = Get-ChildItem -Path $backupDir -Filter *.txt
foreach ($file in $backupFiles) {
    $backupSelector.Items.Add($file.Name)
}
if ($backupFiles.Count -gt 0) {
    $backupSelector.SelectedIndex = 0
}
$form.Controls.Add($backupSelector)

# Instructions
$label = New-Object System.Windows.Forms.Label
$label.Text = "Select the drives to MAP or KEEP mapped. All others will be removed:"
$label.Size = New-Object System.Drawing.Size(600,20)
$label.Location = New-Object System.Drawing.Point(20,60)
$form.Controls.Add($label)

# Info about current serial's backup
$backupInfo = New-Object System.Windows.Forms.Label
$backupInfo.Size = New-Object System.Drawing.Size(600,20)
$backupInfo.Location = New-Object System.Drawing.Point(20,80)
if (Test-Path $backupFile) {
    $info = Get-Item $backupFile
    $backupInfo.Text = "This device's backup: $($info.Name) (Last modified: $($info.LastWriteTime))"
} else {
    $backupInfo.Text = "No backup file found for this device."
}
$form.Controls.Add($backupInfo)

# ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.Size = New-Object System.Drawing.Size(620,400)
$listView.Location = New-Object System.Drawing.Point(20,110)
$listView.View = 'Details'
$listView.CheckBoxes = $true
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Columns.Add("Letter", 50)
$listView.Columns.Add("Name", 120)
$listView.Columns.Add("Path", 300)
$listView.Columns.Add("Current Status", 100)
$form.Controls.Add($listView)

$listView.add_ItemCheck({
    param($sender, $e)
    $currentItem = $listView.Items[$e.Index]
    $currentDrive = $currentItem.Tag
    if ($currentItem.SubItems[3].Text -eq "No Access") {
        $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
        return
    }
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        foreach ($i in 0..($listView.Items.Count - 1)) {
            if ($i -ne $e.Index) {
                $otherItem = $listView.Items[$i]
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
    $listView.Items.Add($item)
}

# Buttons
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Apply"
$okButton.Location = New-Object System.Drawing.Point(270,530)
$okButton.Add_Click({
    $global:cancelled = $false
    $form.Close()
})
$form.Controls.Add($okButton)

$backupButton = New-Object System.Windows.Forms.Button
$backupButton.Text = "Backup"
$backupButton.Location = New-Object System.Drawing.Point(120,530)
$backupButton.Add_Click({
    $currentMappings = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" } |
        ForEach-Object { "$($_.Name): $($_.DisplayRoot)" }
    $currentMappings | Set-Content -Path $backupFile
    [System.Windows.Forms.MessageBox]::Show("Drive mappings backed up to $backupFile")
})
$form.Controls.Add($backupButton)

$restoreButton = New-Object System.Windows.Forms.Button
$restoreButton.Text = "Restore Selected"
$restoreButton.Location = New-Object System.Drawing.Point(430,530)
$restoreButton.Size = New-Object System.Drawing.Size(170,25)
$restoreButton.Add_Click({
    if ($backupSelector.SelectedItem) {
        $selectedFile = Join-Path $backupDir $backupSelector.SelectedItem
        if (Test-Path $selectedFile) {
            $lines = Get-Content $selectedFile
            $lettersToRestore = @{}
            foreach ($line in $lines) {
                if ($line -match "^(\w):\s+(\\\\.+)$") {
                    $lettersToRestore["$($matches[1]):"] = $matches[2]
                }
            }
            foreach ($item in $listView.Items) {
                $drive = $item.Tag
                if ($lettersToRestore.ContainsKey($drive.Letter) -and $lettersToRestore[$drive.Letter] -eq $drive.Path -and $item.SubItems[3].Text -ne "No Access") {
                    $item.Checked = $true
                } else {
                    $item.Checked = $false
                }
            }
            [System.Windows.Forms.MessageBox]::Show("Drive selections updated from backup file: $($backupSelector.SelectedItem)")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Selected backup file not found.")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a backup file from the dropdown list.")
    }
})
$form.Controls.Add($restoreButton)


$quitButton = New-Object System.Windows.Forms.Button
$quitButton.Text = "Quit"
$quitButton.Location = New-Object System.Drawing.Point(270,570)
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
    $selectedDrives = $listView.CheckedItems | ForEach-Object { $_.Tag }

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
