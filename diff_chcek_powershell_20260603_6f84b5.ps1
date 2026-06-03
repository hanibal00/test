# DIAGNOSTIC SCRIPT - Run this first to see what's in your CSVs

$firstReportPath = "C:\Temp\work\Book1.csv"
$secondReportPath = "C:\Temp\work\dpr.csv"

Write-Host "=== DIAGNOSING FIRST CSV (Book1.csv) ===" -ForegroundColor Cyan

# Check if file exists
if (Test-Path $firstReportPath) {
    Write-Host "File found: $firstReportPath" -ForegroundColor Green
    
    # Read first few lines raw to see the actual content
    Write-Host "`nFirst 3 lines of raw file:" -ForegroundColor Yellow
    Get-Content $firstReportPath -TotalCount 3
    
    # Import CSV and show column names
    $firstData = Import-Csv -Path $firstReportPath
    Write-Host "`nColumn names in first CSV:" -ForegroundColor Yellow
    $firstData[0].PSObject.Properties.Name | ForEach-Object { Write-Host "  - '$($_).'" }
    
    Write-Host "`nFirst 3 records (showing all columns):" -ForegroundColor Yellow
    $firstData | Select-Object -First 3 | Format-List
    
    Write-Host "`nChecking for 'failed' status values:" -ForegroundColor Yellow
    $firstData | ForEach-Object {
        # Check all properties for the word 'failed'
        $_.PSObject.Properties | ForEach-Object {
            if ($_.Value -and $_.Value.ToString().ToLower() -match "fail") {
                Write-Host "  Found 'fail' in column '$($_.Name)' with value: '$($_.Value)'" -ForegroundColor Green
            }
        }
    }
    
    # Try to find Status column regardless of case
    $statusColumn = $firstData[0].PSObject.Properties.Name | Where-Object { $_ -like "*status*" }
    if ($statusColumn) {
        Write-Host "`nStatus column found: '$statusColumn'" -ForegroundColor Green
        $uniqueStatuses = $firstData | Where-Object { $_.$statusColumn } | ForEach-Object { $_.$statusColumn.Trim() } | Sort-Object -Unique
        Write-Host "Unique values in Status column:" -ForegroundColor Yellow
        $uniqueStatuses | ForEach-Object { Write-Host "  - '$_'" }
    } else {
        Write-Host "`nNo column containing 'status' was found!" -ForegroundColor Red
    }
} else {
    Write-Host "File NOT found: $firstReportPath" -ForegroundColor Red
}

Write-Host "`n=== DIAGNOSING SECOND CSV (dpr.csv) ===" -ForegroundColor Cyan

if (Test-Path $secondReportPath) {
    Write-Host "File found: $secondReportPath" -ForegroundColor Green
    
    # Read first few lines raw
    Write-Host "`nFirst 3 lines of raw file:" -ForegroundColor Yellow
    Get-Content $secondReportPath -TotalCount 3
    
    # Import CSV and show column names
    $secondData = Import-Csv -Path $secondReportPath
    Write-Host "`nColumn names in second CSV:" -ForegroundColor Yellow
    $secondData[0].PSObject.Properties.Name | ForEach-Object { Write-Host "  - '$($_).'" }
    
    Write-Host "`nChecking for 'WINDOWS SERVER' in Tech family column:" -ForegroundColor Yellow
    $techFamilyColumn = $secondData[0].PSObject.Properties.Name | Where-Object { $_ -like "*tech*" -or $_ -like "*family*" }
    if ($techFamilyColumn) {
        Write-Host "Tech family column found: '$techFamilyColumn'" -ForegroundColor Green
        $uniqueFamilies = $secondData | Where-Object { $_.$techFamilyColumn } | ForEach-Object { $_.$techFamilyColumn.Trim() } | Sort-Object -Unique
        Write-Host "Unique values in Tech family column:" -ForegroundColor Yellow
        $uniqueFamilies | ForEach-Object { Write-Host "  - '$_'" }
    } else {
        Write-Host "No column containing 'tech' or 'family' was found!" -ForegroundColor Red
        Write-Host "Available columns:" -ForegroundColor Yellow
        $secondData[0].PSObject.Properties.Name | ForEach-Object { Write-Host "  - '$_'" }
    }
} else {
    Write-Host "File NOT found: $secondReportPath" -ForegroundColor Red
}