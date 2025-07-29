# SD Card Duplicate File Cleaner
# Removes duplicate files where .zip and other extensions have the same basename
# Optionally compresses orphan files to individual .zip files

param(
    [switch]$Execute = $false,
    [switch]$CompressOrphans = $false
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables for statistics
$script:TotalDuplicatesFound = 0
$script:TotalDuplicatesRemoved = 0
$script:TotalOrphansFound = 0
$script:TotalOrphansCompressed = 0

function Show-DriveSelection {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Drive for Duplicate Cleanup"
    $form.Size = New-Object System.Drawing.Size(300, 150)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(260, 20)
    $label.Text = "Select the drive to scan for duplicate files:"
    $form.Controls.Add($label)

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(10, 50)
    $comboBox.Size = New-Object System.Drawing.Size(260, 20)
    $comboBox.DropDownStyle = "DropDownList"

    # Get drives D: and above
    $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and $_.DeviceID -ge "D:" } | Sort-Object DeviceID
    foreach ($drive in $drives) {
        $driveInfo = "$($drive.DeviceID) - $([math]::Round($drive.Size/1GB, 2)) GB"
        if ($drive.VolumeName) {
            $driveInfo += " ($($drive.VolumeName))"
        }
        $comboBox.Items.Add($driveInfo) | Out-Null
    }

    if ($comboBox.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No drives found (D: or higher)", "Error", "OK", "Error")
        return $null
    }

    $comboBox.SelectedIndex = 0
    $form.Controls.Add($comboBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(115, 85)
    $okButton.Size = New-Object System.Drawing.Size(75, 23)
    $okButton.Text = "OK"
    $okButton.DialogResult = "OK"
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $result = $form.ShowDialog()
    if ($result -eq "OK") {
        $selectedDrive = $comboBox.SelectedItem.ToString().Split(' ')[0]
        return $selectedDrive
    }
    return $null
}

function Test-FileInZip {
    param(
        [string]$ZipPath,
        [string]$FileName,
        [long]$ExpectedSize
    )
    
    try {
        # Create temporary directory for extraction test
        $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            # Extract the specific file
            $shell = New-Object -ComObject Shell.Application
            $zip = $shell.NameSpace($ZipPath)
            $file = $zip.Items() | Where-Object { $_.Name -eq $FileName }
            
            if (-not $file) {
                return $false
            }
            
            # Extract to temp directory
            $dest = $shell.NameSpace($tempDir)
            $dest.CopyHere($file, 4) # 4 = no progress dialog
            
            # Wait for extraction to complete
            $extractedPath = Join-Path $tempDir $FileName
            $timeout = 0
            while (-not (Test-Path $extractedPath) -and $timeout -lt 30) {
                Start-Sleep -Milliseconds 100
                $timeout++
            }
            
            if (Test-Path $extractedPath) {
                $extractedSize = (Get-Item $extractedPath).Length
                return $extractedSize -eq $ExpectedSize
            }
            
            return $false
        }
        finally {
            # Clean up temp directory
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Warning "Error testing file in ZIP: $($_.Exception.Message)"
        return $false
    }
}

function Find-DuplicateFiles {
    param([string]$FolderPath)
    
    $duplicates = @()
    
    try {
        $files = Get-ChildItem -Path $FolderPath -File -ErrorAction SilentlyContinue
        if (-not $files) { 
            return $duplicates 
        }
        
        # Group files by basename (filename without extension)
        $grouped = $files | Group-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
        
        foreach ($group in $grouped) {
            if ($group.Count -lt 2) { 
                continue 
            }
            
            $zipFile = $group.Group | Where-Object { $_.Extension -eq ".zip" }
            $otherFiles = $group.Group | Where-Object { $_.Extension -ne ".zip" }
            
            if ($zipFile -and $otherFiles) {
                foreach ($otherFile in $otherFiles) {
                    Write-Host "  Checking: $($otherFile.Name) vs $($zipFile.Name)..." -ForegroundColor Yellow
                    
                    if (Test-FileInZip -ZipPath $zipFile.FullName -FileName $otherFile.Name -ExpectedSize $otherFile.Length) {
                        $duplicates += @{
                            ZipFile = $zipFile.FullName
                            DuplicateFile = $otherFile.FullName
                            Size = $otherFile.Length
                        }
                        Write-Host "    [MATCH] File verified in ZIP!" -ForegroundColor Green
                    } else {
                        Write-Host "    [NO MATCH] File not in ZIP or size differs" -ForegroundColor Red
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error processing folder $FolderPath - $($_.Exception.Message)"
    }
    
    return $duplicates
}

function Find-OrphanFiles {
    param([string]$FolderPath)
    
    $orphans = @()
    
    try {
        $files = Get-ChildItem -Path $FolderPath -File -ErrorAction SilentlyContinue
        if (-not $files) { 
            return $orphans 
        }
        
        $nonZipFiles = $files | Where-Object { $_.Extension -ne ".zip" }
        
        foreach ($file in $nonZipFiles) {
            $basename = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $correspondingZip = Join-Path $FolderPath "$basename.zip"
            
            if (-not (Test-Path $correspondingZip)) {
                $orphans += $file.FullName
            }
        }
    }
    catch {
        Write-Warning "Error finding orphans in $FolderPath - $($_.Exception.Message)"
    }
    
    return $orphans
}

function Compress-OrphanFile {
    param(
        [string]$FilePath,
        [bool]$DryRun = $true
    )
    
    try {
        $file = Get-Item $FilePath
        $zipPath = Join-Path $file.Directory.FullName "$([System.IO.Path]::GetFileNameWithoutExtension($file.Name)).zip"
        
        if ($DryRun) {
            Write-Host "    Would compress: $($file.Name) -> $([System.IO.Path]::GetFileName($zipPath))" -ForegroundColor Cyan
            return $true
        }
        
        # Compress the file
        Compress-Archive -Path $FilePath -DestinationPath $zipPath -Force
        
        # Verify the compression
        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length
            if ($zipSize -gt 0) {
                # Test if we can extract it back
                if (Test-FileInZip -ZipPath $zipPath -FileName $file.Name -ExpectedSize $file.Length) {
                    Write-Host "    [SUCCESS] Compressed and verified: $($file.Name)" -ForegroundColor Green
                    return $true
                } else {
                    Write-Warning "Compression verification failed for $($file.Name)"
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                    return $false
                }
            }
        }
        
        Write-Warning "Compression failed for $($file.Name)"
        return $false
    }
    catch {
        Write-Warning "Error compressing $FilePath - $($_.Exception.Message)"
        return $false
    }
}

function Show-Confirmation {
    param(
        [string]$Message,
        [string]$Title = "Confirmation"
    )
    
    $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, "YesNo", "Question")
    return $result -eq "Yes"
}

function Process-Folder {
    param(
        [string]$FolderPath,
        [bool]$DryRun = $true,
        [bool]$ProcessOrphans = $false
    )
    
    # Create separator line
    $separator = "=" * 80
    Write-Host ""
    Write-Host $separator -ForegroundColor Cyan
    Write-Host "Processing folder: $FolderPath" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor Cyan
    
    # Phase 1: Find and process duplicates
    Write-Host "`nPhase 1: Scanning for duplicates..." -ForegroundColor Yellow
    $duplicates = Find-DuplicateFiles -FolderPath $FolderPath
    
    if ($duplicates.Count -eq 0) {
        Write-Host "No duplicates found in this folder." -ForegroundColor Green
    } else {
        Write-Host "`nFound $($duplicates.Count) duplicate(s):" -ForegroundColor Yellow
        foreach ($dup in $duplicates) {
            $fileName = [System.IO.Path]::GetFileName($dup.DuplicateFile)
            $sizeMB = [math]::Round($dup.Size / 1MB, 2)
            Write-Host "  - $fileName ($sizeMB MB)" -ForegroundColor White
        }
        
        $script:TotalDuplicatesFound += $duplicates.Count
        
        if ($DryRun) {
            Write-Host "`n[DRY RUN] These files would be deleted." -ForegroundColor Magenta
        } else {
            if (Show-Confirmation -Message "Delete these $($duplicates.Count) duplicate file(s)?" -Title "Confirm Deletion") {
                if (Show-Confirmation -Message "Are you REALLY sure? This action cannot be undone!" -Title "Final Confirmation") {
                    foreach ($dup in $duplicates) {
                        try {
                            Remove-Item $dup.DuplicateFile -Force
                            Write-Host "  [DELETED] $([System.IO.Path]::GetFileName($dup.DuplicateFile))" -ForegroundColor Green
                            $script:TotalDuplicatesRemoved++
                        }
                        catch {
                            Write-Warning "Failed to delete $($dup.DuplicateFile) - $($_.Exception.Message)"
                        }
                    }
                } else {
                    Write-Host "Deletion cancelled by user." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Deletion skipped by user." -ForegroundColor Yellow
            }
        }
    }
    
    # Phase 2: Find and process orphans (if enabled)
    if ($ProcessOrphans) {
        Write-Host "`nPhase 2: Scanning for orphan files..." -ForegroundColor Yellow
        $orphans = Find-OrphanFiles -FolderPath $FolderPath
        
        if ($orphans.Count -eq 0) {
            Write-Host "No orphan files found in this folder." -ForegroundColor Green
        } else {
            Write-Host "`nFound $($orphans.Count) orphan file(s):" -ForegroundColor Yellow
            foreach ($orphan in $orphans) {
                $fileName = [System.IO.Path]::GetFileName($orphan)
                $sizeMB = [math]::Round((Get-Item $orphan).Length / 1MB, 2)
                Write-Host "  - $fileName ($sizeMB MB)" -ForegroundColor White
            }
            
            $script:TotalOrphansFound += $orphans.Count
            
            if ($DryRun) {
                foreach ($orphan in $orphans) {
                    Compress-OrphanFile -FilePath $orphan -DryRun $true | Out-Null
                }
                Write-Host "`n[DRY RUN] These files would be compressed and originals deleted." -ForegroundColor Magenta
            } else {
                if (Show-Confirmation -Message "Compress these $($orphans.Count) orphan file(s) and delete originals?" -Title "Confirm Compression") {
                    if (Show-Confirmation -Message "Are you REALLY sure? Original files will be deleted after compression!" -Title "Final Confirmation") {
                        foreach ($orphan in $orphans) {
                            if (Compress-OrphanFile -FilePath $orphan -DryRun $false) {
                                try {
                                    Remove-Item $orphan -Force
                                    Write-Host "  [PROCESSED] $([System.IO.Path]::GetFileName($orphan))" -ForegroundColor Green
                                    $script:TotalOrphansCompressed++
                                }
                                catch {
                                    Write-Warning "Failed to delete original file $orphan after compression - $($_.Exception.Message)"
                                }
                            }
                        }
                    } else {
                        Write-Host "Compression cancelled by user." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Compression skipped by user." -ForegroundColor Yellow
                }
            }
        }
    }
}

function Main {
    $headerSeparator = "=" * 32
    Write-Host "SD Card Duplicate File Cleaner" -ForegroundColor Green
    Write-Host $headerSeparator -ForegroundColor Green
    
    # Show drive selection
    $selectedDrive = Show-DriveSelection
    if (-not $selectedDrive) {
        Write-Host "No drive selected. Exiting." -ForegroundColor Red
        return
    }
    
    Write-Host "Selected drive: $selectedDrive" -ForegroundColor Green
    
    # Check if drive exists
    if (-not (Test-Path $selectedDrive)) {
        Write-Host "Drive $selectedDrive not accessible. Exiting." -ForegroundColor Red
        return
    }
    
    # Determine run mode
    $dryRun = -not $Execute
    $processOrphans = $CompressOrphans
    
    if ($dryRun) {
        Write-Host "`n*** DRY RUN MODE - No files will be deleted ***" -ForegroundColor Magenta
        Write-Host "Use -Execute parameter to actually delete files" -ForegroundColor Magenta
    }
    
    if ($processOrphans) {
        Write-Host "*** ORPHAN COMPRESSION ENABLED ***" -ForegroundColor Cyan
    }
    
    # Get all folders recursively
    Write-Host "`nScanning for folders..." -ForegroundColor Yellow
    try {
        $folders = Get-ChildItem -Path $selectedDrive -Directory -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName
        Write-Host "Found $($folders.Count) folders to process." -ForegroundColor Green
        
        # Process each folder
        foreach ($folder in $folders) {
            Process-Folder -FolderPath $folder.FullName -DryRun $dryRun -ProcessOrphans $processOrphans
            
            # Ask to continue to next folder
            if (-not $dryRun -and $folders.IndexOf($folder) -lt ($folders.Count - 1)) {
                if (-not (Show-Confirmation -Message "Continue to next folder?" -Title "Continue Processing")) {
                    Write-Host "Processing stopped by user." -ForegroundColor Yellow
                    break
                }
            }
        }
        
        # Show final statistics
        $finalSeparator = "=" * 80
        Write-Host ""
        Write-Host $finalSeparator -ForegroundColor Green
        Write-Host "FINAL SUMMARY" -ForegroundColor Green
        Write-Host $finalSeparator -ForegroundColor Green
        Write-Host "Duplicates found: $script:TotalDuplicatesFound" -ForegroundColor White
        Write-Host "Duplicates removed: $script:TotalDuplicatesRemoved" -ForegroundColor White
        if ($processOrphans) {
            Write-Host "Orphans found: $script:TotalOrphansFound" -ForegroundColor White
            Write-Host "Orphans compressed: $script:TotalOrphansCompressed" -ForegroundColor White
        }
        Write-Host $finalSeparator -ForegroundColor Green
        
    }
    catch {
        Write-Host "Error during processing: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run the main function
Main
