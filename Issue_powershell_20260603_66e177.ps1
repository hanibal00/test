# ADAPTED SCRIPT - Replace column names with what you found in diagnostics

$firstReportPath = "C:\Temp\work\Book1.csv"
$secondReportPath = "C:\Temp\work\dpr.csv"
$outputReportPath = "C:\Temp\work\output_report.csv"

# First, determine the actual column names from your files
$firstSample = Import-Csv -Path $firstReportPath | Select-Object -First 1
$secondSample = Import-Csv -Path $secondReportPath | Select-Object -First 1

# OPTION 1: Let script auto-detect column names
$statusColumn = ($firstSample.PSObject.Properties.Name | Where-Object { $_ -like "*status*" })[0]
$clientColumn = ($firstSample.PSObject.Properties.Name | Where-Object { $_ -like "*client*" -or $_ -like "*host*" })[0]
$techFamilyColumn = ($secondSample.PSObject.Properties.Name | Where-Object { $_ -like "*tech*" -or $_ -like "*family*" })[0]
$hostColumn = ($secondSample.PSObject.Properties.Name | Where-Object { $_ -like "*host*" -or $_ -like "*name*" })[0]

Write-Host "Detected columns:" -ForegroundColor Cyan
Write-Host "  Status column: '$statusColumn'"
Write-Host "  Client column: '$clientColumn'"
Write-Host "  Tech Family column: '$techFamilyColumn'"
Write-Host "  Host column: '$hostColumn'"

# Import and filter using detected column names
$firstReport = Import-Csv -Path $firstReportPath
$secondReport = Import-Csv -Path $secondReportPath

# Filter using the detected column names
$failedRecords = $firstReport | Where-Object { 
    $_.$statusColumn -and $_.$statusColumn.Trim().ToLower() -eq "failed"
}

$windowsServers = $secondReport | Where-Object { 
    $_.$techFamilyColumn -and $_.$techFamilyColumn.Trim().ToUpper() -eq "WINDOWS SERVER"
}

Write-Host "`nFound $($failedRecords.Count) failed records" -ForegroundColor Green
Write-Host "Found $($windowsServers.Count) Windows Server records" -ForegroundColor Green

# Create lookup and match
$hostLookup = @{}
foreach ($server in $windowsServers) {
    $hostName = $server.$hostColumn.Trim().ToUpper()
    $hostLookup[$hostName] = $server
}

$results = @()
foreach ($failed in $failedRecords) {
    $clientName = $failed.$clientColumn.Trim().ToUpper()
    if ($hostLookup.ContainsKey($clientName)) {
        $results += [PSCustomObject]@{
            Client = $failed.$clientColumn
            Status = $failed.$statusColumn
            Host = $hostLookup[$clientName].$hostColumn
            TechFamily = $hostLookup[$clientName].$techFamilyColumn
        }
        Write-Host "Match: $clientName" -ForegroundColor Green
    }
}

$results | Export-Csv -Path $outputReportPath -NoTypeInformation -Encoding UTF8
Write-Host "`nExported $($results.Count) matching records to $outputReportPath" -ForegroundColor Green