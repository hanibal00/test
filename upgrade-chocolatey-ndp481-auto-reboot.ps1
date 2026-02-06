# Simple Chocolatey Upgrade Script with .NET Framework 4.8.1 Installation
# AUTO REBOOT VERSION - Uses NDP481-x86-x64-AllOS-ENU.exe installer
# SIMPLIFIED PROGRESS OUTPUT

# Path to the .NET Framework 4.8.1 installer
$dotnetInstaller = "NDP481-x86-x64-AllOS-ENU.exe"

Write-Host "Attempting Chocolatey upgrade..." -ForegroundColor Cyan

# Try to upgrade Chocolatey (suppress progress)
$output = choco upgrade chocolatey -y --force --no-progress 2>&1 | Out-String
Write-Host $output

# Check if the upgrade failed due to .NET Framework requirement
if ($LASTEXITCODE -ne 0 -and $output -match "requires \.NET Framework 4\.8 or higher") {
    
    Write-Host "`nDetected .NET Framework 4.8 requirement. Installing .NET Framework 4.8.1...`n" -ForegroundColor Yellow
    
    # Check if installer exists
    if (-not (Test-Path $dotnetInstaller)) {
        Write-Host "ERROR: Installer not found: $dotnetInstaller" -ForegroundColor Red
        Write-Host "Please ensure NDP481-x86-x64-AllOS-ENU.exe is in the current directory." -ForegroundColor Yellow
        exit 1
    }
    
    # Install .NET Framework 4.8.1 silently
    Write-Host "Running .NET Framework 4.8.1 installer silently..." -ForegroundColor Cyan
    $installProcess = Start-Process -FilePath $dotnetInstaller -ArgumentList "/q /norestart" -Wait -PassThru
    
    if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
        # Exit code 0 = success, 3010 = success but reboot required
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host ".NET Framework 4.8.1 installed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "`nSystem will restart in 10 seconds..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to cancel the restart`n" -ForegroundColor Cyan
        
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    else {
        Write-Host "`nFailed to install .NET Framework 4.8.1. Exit code: $($installProcess.ExitCode)" -ForegroundColor Red
        exit 1
    }
}
elseif ($LASTEXITCODE -eq 0) {
    Write-Host "`nChocolatey upgraded successfully!" -ForegroundColor Green
}
else {
    Write-Host "`nChocolatey upgrade failed. Check error message above." -ForegroundColor Red
}
