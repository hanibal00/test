# FIXED SCRIPT - For your specific CSV format with spaces and dots in column names

$firstReportPath = "C:\Temp\work\Book1.csv"
$secondReportPath = "C:\Temp\work\dpr.csv"
$outputReportPath = "C:\Temp\work\output_report.csv"

function Compare-CSVReports-Fixed {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FirstCSV,
        
        [Parameter(Mandatory=$true)]
        [string]$SecondCSV,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputCSV
    )
    
    # Check if input files exist
    if (-not (Test-Path $FirstCSV)) {
        Write-Error "First CSV file not found: $FirstCSV"
        return $false
    }
    
    if (-not (Test-Path $SecondCSV)) {
        Write-Error "Second CSV file not found: $SecondCSV"
        return $false
    }
    
    try {
        # Import both CSV files
        Write-Host "Importing first report: $FirstCSV" -ForegroundColor Cyan
        $firstReport = Import-Csv -Path $FirstCSV
        
        Write-Host "Importing second report: $SecondCSV" -ForegroundColor Cyan
        $secondReport = Import-Csv -Path $SecondCSV
        
        # Display column names for verification
        Write-Host "`nFirst CSV columns:" -ForegroundColor Yellow
        $firstReport[0].PSObject.Properties.Name | ForEach-Object { Write-Host "  - '$_'" }
        
        Write-Host "`nSecond CSV columns (first few):" -ForegroundColor Yellow
        $secondReport[0].PSObject.Properties.Name | Select-Object -First 10 | ForEach-Object { Write-Host "  - '$_'" }
        
        # IMPORTANT: Use the exact column names with spaces and dots
        # First CSV: ' Status ' has spaces, 'Client' column name - adjust if needed
        $statusColumn = ' Status '  # Note the spaces!
        
        # Find the Client column in first CSV (could be 'Client', 'client', etc.)
        $clientColumn = $firstReport[0].PSObject.Properties.Name | Where-Object { $_ -like "*client*" } | Select-Object -First 1
        
        # Second CSV columns have dots at the end
        $hostColumn = 'Host.'  # Note the dot!
        $techFamilyColumn = 'Tech family.'  # Note the dot!
        
        Write-Host "`nUsing columns:" -ForegroundColor Green
        Write-Host "  Status column: '$statusColumn'"
        Write-Host "  Client column: '$clientColumn'"
        Write-Host "  Host column: '$hostColumn'"
        Write-Host "  Tech Family column: '$techFamilyColumn'"
        
        # Filter first report for Status = "failed" (using the exact column name with spaces)
        $failedRecords = $firstReport | Where-Object { 
            $_.$statusColumn -and $_.$statusColumn.Trim().ToLower() -eq "failed"
        }
        
        if ($failedRecords.Count -eq 0) {
            Write-Host "`nNo records with Status='failed' found in the first report." -ForegroundColor Yellow
            Write-Host "Available status values:" -ForegroundColor Yellow
            $firstReport | ForEach-Object { $_.$statusColumn } | Sort-Object -Unique | ForEach-Object { Write-Host "  - '$_'" }
            return $false
        }
        
        Write-Host "`nFound $($failedRecords.Count) failed records in first report" -ForegroundColor Green
        
        # Filter second report for Tech family = "WINDOWS SERVER" (case-insensitive)
        $windowsServers = $secondReport | Where-Object { 
            $_.$techFamilyColumn -and $_.$techFamilyColumn.Trim().ToUpper() -eq "WINDOWS SERVER"
        }
        
        if ($windowsServers.Count -eq 0) {
            Write-Host "`nNo records with Tech family='WINDOWS SERVER' found in the second report." -ForegroundColor Yellow
            Write-Host "Available Tech family values (first 20 unique):" -ForegroundColor Yellow
            $secondReport | ForEach-Object { $_.$techFamilyColumn } | Where-Object { $_ } | Sort-Object -Unique | Select-Object -First 20 | ForEach-Object { Write-Host "  - '$_'" }
            return $false
        }
        
        Write-Host "Found $($windowsServers.Count) Windows Server records in second report" -ForegroundColor Green
        
        # Create a hashtable for case-insensitive lookup using Host column
        $hostLookup = @{}
        foreach ($server in $windowsServers) {
            # Convert Host name to UPPERCASE for consistent matching (remove any trailing spaces)
            $hostName = $server.$hostColumn.Trim().ToUpper()
            if (-not $hostLookup.ContainsKey($hostName)) {
                $hostLookup[$hostName] = $server
            }
        }
        
        Write-Host "`nHost lookup table created with $($hostLookup.Count) unique Windows Server hosts" -ForegroundColor Green
        
        # Compare and extract matching records
        $matchingResults = @()
        $noMatchCount = 0
        
        foreach ($failed in $failedRecords) {
            # Convert Client name to UPPERCASE for matching
            $clientName = $failed.$clientColumn.Trim().ToUpper()
            
            # Check if client name exists in the host lookup
            if ($hostLookup.ContainsKey($clientName)) {
                # Create combined result object
                $result = [PSCustomObject]@{
                    # Fields from first report
                    Client = $failed.$clientColumn
                    Status = $failed.$statusColumn
                    
                    # Fields from second report
                    Host = $hostLookup[$clientName].$hostColumn
                    TechFamily = $hostLookup[$clientName].$techFamilyColumn
                    # Add more fields from second report if needed:
                    # Datacenter = $hostLookup[$clientName].'Datacenter.'
                    # LiveStatus = $hostLookup[$clientName].'Live status.'
                    # OSFamily = $hostLookup[$clientName].'OSFamily.'
                }
                
                $matchingResults += $result
                Write-Host "Match found: Client '$($failed.$clientColumn)' -> Host '$($hostLookup[$clientName].$hostColumn)'" -ForegroundColor Green
            }
            else {
                $noMatchCount++
                Write-Host "No match found for client: '$($failed.$clientColumn)'" -ForegroundColor Gray
            }
        }
        
        # Export results to third CSV
        if ($matchingResults.Count -gt 0) {
            $matchingResults | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "SUCCESSFULLY EXPORTED $($matchingResults.Count) matching records" -ForegroundColor Green
            Write-Host "Output file: $OutputCSV" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Cyan
            
            # Display summary
            Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
            Write-Host "Failed records in first report: $($failedRecords.Count)"
            Write-Host "Windows Server records in second report: $($windowsServers.Count)"
            Write-Host "Matching records found: $($matchingResults.Count)"
            Write-Host "Non-matching clients: $noMatchCount"
            if ($failedRecords.Count -gt 0) {
                Write-Host "Match rate: $([math]::Round(($matchingResults.Count / $failedRecords.Count) * 100, 2))%"
            }
            
            # Show first 5 matches as preview
            Write-Host "`n=== PREVIEW OF RESULTS (first 5) ===" -ForegroundColor Cyan
            $matchingResults | Select-Object -First 5 | Format-Table -AutoSize
        }
        else {
            Write-Host "`nNo matching records found to export." -ForegroundColor Yellow
            Write-Host "`nFirst 5 client names from failed records:" -ForegroundColor Yellow
            $failedRecords | Select-Object -First 5 | ForEach-Object { Write-Host "  - '$($_.$clientColumn)'" }
            Write-Host "`nFirst 5 host names from Windows Server records:" -ForegroundColor Yellow
            $windowsServers | Select-Object -First 5 | ForEach-Object { Write-Host "  - '$($_.$hostColumn)'" }
            return $false
        }
        
        return $true
    }
    catch {
        Write-Error "An error occurred: $_"
        Write-Error "Error details: $($_.Exception.Message)"
        return $false
    }
}

# Alternative version that includes MORE columns from the second report
function Compare-CSVReports-WithMoreColumns {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FirstCSV,
        
        [Parameter(Mandatory=$true)]
        [string]$SecondCSV,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputCSV
    )
    
    try {
        $firstReport = Import-Csv -Path $FirstCSV
        $secondReport = Import-Csv -Path $SecondCSV
        
        $statusColumn = ' Status '
        $clientColumn = $firstReport[0].PSObject.Properties.Name | Where-Object { $_ -like "*client*" } | Select-Object -First 1
        $hostColumn = 'Host.'
        $techFamilyColumn = 'Tech family.'
        
        $failedRecords = $firstReport | Where-Object { $_.$statusColumn.Trim().ToLower() -eq "failed" }
        $windowsServers = $secondReport | Where-Object { $_.$techFamilyColumn.Trim().ToUpper() -eq "WINDOWS SERVER" }
        
        $hostLookup = @{}
        foreach ($server in $windowsServers) {
            $hostLookup[$server.$hostColumn.Trim().ToUpper()] = $server
        }
        
        $results = @()
        foreach ($failed in $failedRecords) {
            $clientName = $failed.$clientColumn.Trim().ToUpper()
            if ($hostLookup.ContainsKey($clientName)) {
                $server = $hostLookup[$clientName]
                $result = [PSCustomObject]@{
                    # From first report
                    Client = $failed.$clientColumn
                    Status = $failed.$statusColumn
                    
                    # From second report - key fields
                    Host = $server.$hostColumn
                    TechFamily = $server.$techFamilyColumn
                    LiveStatus = $server.'Live status.'
                    Datacenter = $server.'Datacenter.'
                    OSFamily = $server.'OSFamily.'
                    Environment = $server.'environment.'
                    Manufacturer = $server.'Manufacturer.'
                    Model = $server.'model.'
                }
                $results += $result
            }
        }
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
            Write-Host "Exported $($results.Count) records with additional columns" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Error "Error: $_"
        return $false
    }
}

# === RUN THE SCRIPT ===
Compare-CSVReports-Fixed -FirstCSV $firstReportPath -SecondCSV $secondReportPath -OutputCSV $outputReportPath

# Uncomment below if you want more columns in the output:
# Compare-CSVReports-WithMoreColumns -FirstCSV $firstReportPath -SecondCSV $secondReportPath -OutputCSV $outputReportPath