# PowerShell 5.1 Script to compare CSV reports
# Usage: Place this script in the same folder as your CSV files or provide full paths

# Define file paths (update these paths as needed)
$firstReportPath = "C:\Reports\first_report.csv"
$secondReportPath = "C:\Reports\second_report.csv"
$outputReportPath = "C:\Reports\output_report.csv"

# Function to compare and extract data
function Compare-CSVReports {
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
        
        # Filter first report for Status = "failed" (case-insensitive)
        $failedRecords = $firstReport | Where-Object { 
            $_.Status -and $_.Status.Trim() -eq "failed"
        }
        
        if ($failedRecords.Count -eq 0) {
            Write-Host "No records with Status='failed' found in the first report." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "Found $($failedRecords.Count) failed records in first report" -ForegroundColor Green
        
        # Filter second report for Tech family = "WINDOWS SERVER" (case-insensitive)
        $windowsServers = $secondReport | Where-Object { 
            $_.'Tech family' -and $_.'Tech family'.Trim() -eq "WINDOWS SERVER"
        }
        
        if ($windowsServers.Count -eq 0) {
            Write-Host "No records with Tech family='WINDOWS SERVER' found in the second report." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "Found $($windowsServers.Count) Windows Server records in second report" -ForegroundColor Green
        
        # Create a hashtable for faster lookup from second report using Host as key
        $hostLookup = @{}
        foreach ($server in $windowsServers) {
            $hostName = $server.Host.Trim()
            if (-not $hostLookup.ContainsKey($hostName)) {
                $hostLookup[$hostName] = $server
            }
        }
        
        # Compare and extract matching records
        $matchingResults = @()
        
        foreach ($failed in $failedRecords) {
            $clientName = $failed.Client.Trim()
            
            # Check if client name exists in the host lookup
            if ($hostLookup.ContainsKey($clientName)) {
                # Create combined result object
                $result = [PSCustomObject]@{
                    # Fields from first report
                    Client = $failed.Client
                    Status = $failed.Status
                    # Add other columns from first report if needed
                    # FirstReportOtherColumns = $failed.OtherColumn
                    
                    # Fields from second report
                    Host = $hostLookup[$clientName].Host
                    TechFamily = $hostLookup[$clientName].'Tech family'
                    # Add other columns from second report if needed
                    # SecondReportOtherColumns = $hostLookup[$clientName].OtherColumn
                }
                
                $matchingResults += $result
                Write-Host "Match found: Client '$clientName' matches Host '$clientName'" -ForegroundColor Green
            }
            else {
                Write-Host "No match found for client: $clientName" -ForegroundColor Gray
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
            Write-Host "Matching percentage: $([math]::Round(($matchingResults.Count / $failedRecords.Count) * 100, 2))%"
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

# Alternative: Function to include ALL columns from both CSVs in the output
function Compare-CSVReports-AllColumns {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FirstCSV,
        
        [Parameter(Mandatory=$true)]
        [string]$SecondCSV,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputCSV
    )
    
    if (-not (Test-Path $FirstCSV) -or -not (Test-Path $SecondCSV)) {
        Write-Error "Input files not found"
        return $false
    }
    
    try {
        $firstReport = Import-Csv -Path $FirstCSV
        $secondReport = Import-Csv -Path $SecondCSV
        
        $failedRecords = $firstReport | Where-Object { $_.Status -eq "failed" }
        $windowsServers = $secondReport | Where-Object { $_.'Tech family' -eq "WINDOWS SERVER" }
        
        $hostLookup = @{}
        foreach ($server in $windowsServers) {
            $hostLookup[$server.Host.Trim()] = $server
        }
        
        $results = @()
        foreach ($failed in $failedRecords) {
            $clientName = $failed.Client.Trim()
            if ($hostLookup.ContainsKey($clientName)) {
                # Create a custom object with properties from both CSVs
                $mergedObject = [PSCustomObject]@{}
                
                # Add all properties from first report
                $failed.PSObject.Properties | ForEach-Object {
                    Add-Member -InputObject $mergedObject -MemberType NoteProperty -Name "First_$($_.Name)" -Value $_.Value
                }
                
                # Add all properties from second report (matching host)
                $hostLookup[$clientName].PSObject.Properties | ForEach-Object {
                    Add-Member -InputObject $mergedObject -MemberType NoteProperty -Name "Second_$($_.Name)" -Value $_.Value
                }
                
                $results += $mergedObject
            }
        }
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
            Write-Host "Exported $($results.Count) records to $OutputCSV with all columns" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Error "Error: $_"
        return $false
    }
}

# === MAIN EXECUTION ===
# Uncomment the function you want to use:

# Option 1: Basic output with selected columns
Compare-CSVReports -FirstCSV $firstReportPath -SecondCSV $secondReportPath -OutputCSV $outputReportPath

# Option 2: Output with ALL columns from both CSVs (uncomment to use)
# Compare-CSVReports-AllColumns -FirstCSV $firstReportPath -SecondCSV $secondReportPath -OutputCSV $outputReportPath

# Option 3: Interactive mode - prompt for file paths
<#
$firstFile = Read-Host "Enter path to first CSV (with Status and Client columns)"
$secondFile = Read-Host "Enter path to second CSV (with Host and Tech family columns)"
$outputFile = Read-Host "Enter path for output CSV"
Compare-CSVReports -FirstCSV $firstFile -SecondCSV $secondFile -OutputCSV $outputFile
#>