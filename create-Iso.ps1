# Complete ISO Creator with GUI folder selection
Add-Type -AssemblyName System.Windows.Forms

Function Create-ISOFromFolder {
    # Create folder browser dialog
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the folder to convert to ISO"
    $folderBrowser.ShowNewFolderButton = $false
    
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $sourceFolder = $folderBrowser.SelectedPath
        
        # Create save file dialog for ISO
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "ISO Files (*.iso)|*.iso"
        $saveFileDialog.Title = "Save ISO As"
        $saveFileDialog.FileName = [System.IO.Path]::GetFileName($sourceFolder) + ".iso"
        
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $outputISO = $saveFileDialog.FileName
            
            # Prompt for volume name
            $volumeName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Volume Name:", "ISO Settings", [System.IO.Path]::GetFileName($sourceFolder))
            
            if ([string]::IsNullOrWhiteSpace($volumeName)) {
                $volumeName = "MyISO"
            }
            
            # Create ISO
            Write-Host "Creating ISO from: $sourceFolder" -ForegroundColor Yellow
            Write-Host "Output: $outputISO" -ForegroundColor Yellow
            
            try {
                if (Get-Command New-IsoFile -ErrorAction SilentlyContinue) {
                    New-IsoFile -Path $sourceFolder -Destination $outputISO -VolumeName $volumeName -Force
                    Write-Host "✓ ISO created successfully!" -ForegroundColor Green
                }
                else {
                    Write-Warning "New-IsoFile not available, using COM method..."
                    New-ISOUsingCOM -SourceFolder $sourceFolder -OutputISO $outputISO -VolumeName $volumeName
                }
            }
            catch {
                Write-Error "Failed to create ISO: $($_.Exception.Message)"
            }
        }
    }
}

# Run the function
