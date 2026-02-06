# PowerShell script to upgrade Chocolatey with automatic .NET Framework 4.8 installation
# NO REBOOT VERSION - Script will not restart the computer

# Configuration
$localNugetRepo = "https://artifactory-mysite/artifactory/api/nuget/wintelapi-nuget-local-release"
$dotnetPackageName = "dotnet48"

# Function to check if .NET Framework 4.8 or higher is installed
function Test-DotNet48Installed {
    try {
        $release = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction Stop
        # .NET 4.8 = 528040, .NET 4.8.1 = 533320
        return ($release.Release -ge 528040)
    }
    catch {
        return $false
    }
}

# Function to install .NET Framework 4.8 from local repository
function Install-DotNet48FromLocal {
    Write-Host "Installing .NET Framework 4.8 from local repository..." -ForegroundColor Yellow
    
    try {
        # Install dotnet48 from the local source
        $installOutput = choco install $dotnetPackageName -y --source=$localNugetRepo 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ".NET Framework 4.8 installed successfully!" -ForegroundColor Green
            Write-Host "NOTE: A system restart is required for .NET Framework installation to complete." -ForegroundColor Cyan
            Write-Host "Please restart your computer manually when convenient." -ForegroundColor Yellow
            return $true
        }
        else {
            Write-Host "Failed to install .NET Framework 4.8. Exit code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host $installOutput
            return $false
        }
    }
    catch {
        Write-Host "Error installing .NET Framework 4.8: $_" -ForegroundColor Red
        return $false
    }
}

# Main script execution
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Chocolatey Upgrade Script with .NET Check" -ForegroundColor Cyan
Write-Host "NO REBOOT VERSION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# First attempt to upgrade Chocolatey
Write-Host "Attempting to upgrade Chocolatey..." -ForegroundColor Yellow

$upgradeOutput = choco upgrade chocolatey -y --force 2>&1 | Out-String
$upgradeExitCode = $LASTEXITCODE

# Display the output
Write-Host $upgradeOutput

# Check if upgrade failed due to .NET Framework requirement
if ($upgradeExitCode -ne 0) {
    if ($upgradeOutput -match "requires \.NET Framework 4\.8 or higher" -or 
        $upgradeOutput -match "Chocolatey cannot be updated because it requires \.NET Framework") {
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "ERROR DETECTED: .NET Framework 4.8 Required" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        
        # Check if .NET 4.8 is actually installed (registry check)
        if (Test-DotNet48Installed) {
            Write-Host ".NET Framework 4.8+ appears to be installed but Chocolatey upgrade still failed." -ForegroundColor Yellow
            Write-Host "This might require a system restart to complete a previous .NET installation." -ForegroundColor Yellow
            Write-Host "Please restart your computer and try again." -ForegroundColor Yellow
            exit 1
        }
        
        # Install .NET Framework 4.8 from local repository
        Write-Host "Installing .NET Framework 4.8 from local repository: $localNugetRepo" -ForegroundColor Cyan
        
        $dotnetInstalled = Install-DotNet48FromLocal
        
        if ($dotnetInstalled) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "NEXT STEPS:" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "1. Restart your computer to complete .NET Framework 4.8 installation" -ForegroundColor White
            Write-Host "2. After restart, run this command again:" -ForegroundColor White
            Write-Host "   choco upgrade chocolatey -y --force" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
        else {
            Write-Host "Failed to install .NET Framework 4.8. Please install manually." -ForegroundColor Red
            exit 1
        }
    }
    else {
        # Different error occurred
        Write-Host ""
        Write-Host "Chocolatey upgrade failed with a different error (not .NET related)." -ForegroundColor Red
        Write-Host "Please review the error message above." -ForegroundColor Yellow
        exit $upgradeExitCode
    }
}
else {
    # Upgrade succeeded on first attempt
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS: Chocolatey upgraded successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}
