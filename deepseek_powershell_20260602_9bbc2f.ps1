# PowerShell 5.1 Script - CASE-INSENSITIVE comparison
# Handles mixed case like "failed" vs "FAILED" and "ClientName" vs "CLIENTNAME"

# Define file paths (update these paths as needed)
$firstReportPath = "C:\Reports\first_report.csv"
$secondReportPath = "C:\Reports\second_report.csv"
$outputReportPath = "C:\Reports\output_report.csv"

function Compare-CSVReports-CaseInsensitive {
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
        
        # Filter first report for Status = "failed" (CASE-INSENSITIVE using ToLower())
        $failedRecords = $firstReport | Where-Object { 
            $_.Status -and $_.Status.Trim().ToLower() -eq "failed"
        }
        
        if ($failedRecords.Count -eq 0) {
            Write-Host "No records with Status='failed' (case-insensitive) found in the first report." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "Found $($failedRecords.Count) failed records in first report" -ForegroundColor Green
        
        # Filter second report for Tech family = "WINDOWS SERVER" (CASE-INSENSITIVE)
        $windowsServers = $secondReport | Where-Object { 
            $_.'Tech family' -and $_.'Tech family'.Trim().ToUpper() -eq "WINDOWS SERVER"
        }
        
        if ($windowsServers.Count -eq 0) {
            Write-Host "No records with Tech family='WINDOWS SERVER' (case-insensitive) found in the second report." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "Found $($windowsServers.Count) Windows Server records in second report" -ForegroundColor Green
        
        # Create a hashtable for case-insensitive lookup
        # Using ToUpper() on the key for consistent case-insensitive matching
        $hostLookup = @{}
        foreach ($server in $windowsServers) {
            # Convert Host name to UPPERCASE for consistent lookup key
            $hostName = $server.Host.Trim().ToUpper()
            if (-not $hostLookup.ContainsKey($hostName)) {
                $hostLookup[$hostName] = $server
            }
        }
        
        # Compare and extract matching records
        $matchingResults = @()
        
        foreach ($failed in $failedRecords) {
            # Convert Client name to UPPERCASE for matching
            $clientName = $failed.Client.Trim().ToUpper()
            
            # Check if client name exists in the host lookup (both now uppercase)
            if ($hostLookup.ContainsKey($clientName)) {
                # Create combined result object
                $result = [PSCustomObject]@{
                    # Fields from first report (keep original case for display)
                    Client = $failed.Client
                    Status = $failed.Status
                    
                    # Fields from second report (keep original case for display)
                    Host = $hostLookup[$clientName].Host
                    TechFamily = $hostLookup[$clientName].'Tech family'
                }
                
                $matchingResults += $result
                Write-Host "Match found: Client '$($failed.Client)' matches Host '$($hostLookup[$clientName].Host)'" -ForegroundColor Green
            }
            else {
                Write-Host "No match found for client: $($failed.Client) (looked for: $clientName)" -ForegroundColor Gray
            }
        }
        
        # Export results to third CSV
        if ($matchingResults.Count -gt 0) {
            $matchingResults | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
            Write-Host "`nSuccessfully exported $($matchingResults.Count) matching records to: $OutputCSV" -ForegroundColor Green
            
            # Display summary
            Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
            Write-Host "Failed records in first report: $($failedRecords.Count)"
            Write-Host "Windows Server records in second report: $($windowsServers.Count)"
            Write-Host "Matching records found: $($matchingResults.Count)"
            if ($failedRecords.Count -gt 0) {
                Write-Host "Matching percentage: $([math]::Round(($matchingResults.Count / $failedRecords.Count) * 100, 2))%"
            }
        }
        else {
            Write-Host "No matching records found to export." -ForegroundColor Yellow
            return $false
        }
        
        return $true
    }
    catch {
        Write-Error "An error occurred: $_"
        return $false
    }
}

# Alternative: Simpler version using -like operator with wildcards (also case-insensitive)
function Compare-CSVReports-Simple {
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
        
        # Case-insensitive filtering using -like with wildcards or -eq (PowerShell default)
        $failedRecords = $firstReport | Where-Object { $_.Status -like "failed" }
        $windowsServers = $secondReport | Where-Object { $_.'Tech family' -like "WINDOWS SERVER" }
        
        # Create lookup with case-insensitive comparison using StringComparer
        $hostLookup = @{}
        foreach ($server in $windowsServers) {
            $key = $server.Host.Trim()
            if (-not $hostLookup.ContainsKey($key)) {
                $hostLookup[$key] = $server
            }
        }
        
        $results = @()
        foreach ($failed in $failedRecords) {
            $clientName = $failed.Client.Trim()
            
            # Manual case-insensitive lookup
            $matched = $hostLookup.Keys | Where-Object { $_ -eq $clientName }
            
            if ($matched) {
                $results += [PSCustomObject]@{
                    Client = $failed.Client
                    Status = $failed.Status
                    Host = $hostLookup[$matched].Host
                    TechFamily = $hostLookup[$matched].'Tech family'
                }
            }
        }
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
            Write-Host "Exported $($results.Count) records (case-insensitive matching)" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Error "Error: $_"
        return $false
    }
}

# === MAIN EXECUTION ===
# Using the explicit case-insensitive version (recommended)
Compare-CSVReports-CaseInsensitive -FirstCSV $firstReportPath -SecondCSV $secondReportPath -OutputCSV $outputReportPath

# Alternative simple version (uncomment to use):
# Compare-CSVReports-Simple -FirstCSV $firstReportPath -SecondCSV $secondReportPath -OutputCSV $outputReportPath