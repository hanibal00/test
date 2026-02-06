# Simple Chocolatey Upgrade Script with .NET Framework 4.8 Auto-Install
# NO REBOOT VERSION - Uses default Chocolatey repository

Write-Host "Attempting Chocolatey upgrade..." -ForegroundColor Cyan

# Try to upgrade Chocolatey
$output = choco upgrade chocolatey -y --force 2>&1 | Out-String
Write-Host $output

# Check if the upgrade failed due to .NET Framework requirement
if ($LASTEXITCODE -ne 0 -and $output -match "requires \.NET Framework 4\.8 or higher") {
    
    Write-Host "`nDetected .NET Framework 4.8 requirement. Installing from Chocolatey...`n" -ForegroundColor Yellow
    
    # Install .NET Framework 4.8 from default Chocolatey repository
    choco install dotnet48 -y
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host ".NET Framework 4.8 installed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "`nNEXT STEPS:" -ForegroundColor Yellow
        Write-Host "1. Restart your computer manually" -ForegroundColor White
        Write-Host "2. After restart, run: choco upgrade chocolatey -y --force`n" -ForegroundColor Cyan
    }
    else {
        Write-Host "`nFailed to install .NET Framework 4.8" -ForegroundColor Red
    }
}
elseif ($LASTEXITCODE -eq 0) {
    Write-Host "`nChocolatey upgraded successfully!" -ForegroundColor Green
}
else {
    Write-Host "`nChocolatey upgrade failed. Check error message above." -ForegroundColor Red
}
