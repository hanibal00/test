param(
    [Parameter(Mandatory)]
    [string]$ServerName,
    
    [Parameter(Mandatory)]
    [int]$TimePeriod
)

# CBS log location
$cbsPath = "C:\Windows\Logs\CBS"

# Calculate time filter
$startTime = (Get-Date).AddHours(-$TimePeriod)

# Result collections using .NET for performance
$errorsList = [System.Collections.Generic.List[object]]::new()
$warningsList = [System.Collections.Generic.List[object]]::new()

# Performance timer
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Get all CBS log files
if (![System.IO.Directory]::Exists($cbsPath)) {
    Write-Error "CBS path not found: $cbsPath"
    exit 1
}

$logFiles = [System.IO.Directory]::GetFiles($cbsPath, "CBS*.log")

if ($logFiles.Count -eq 0) {
    Write-Warning "No CBS log files found"
    exit 0
}

Write-Host "Processing $($logFiles.Count) log file(s)..." -ForegroundColor Cyan

# Process each file
foreach ($file in $logFiles) {
    $fileName = [System.IO.Path]::GetFileName($file)
    
    try {
        # Use .NET StreamReader for performance
        $reader = [System.IO.StreamReader]::new($file, [System.Text.Encoding]::UTF8)
        $lineNum = 0
        
        while ($null -ne ($line = $reader.ReadLine())) {
            $lineNum++
            
            # Skip if no error or warning
            if ($line -notmatch 'error|warning') { continue }
            
            # Parse timestamp (format: 2025-02-09 10:15:23)
            $timestamp = $null
            if ($line -match '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}') {
                try {
                    $timestamp = [DateTime]::ParseExact($line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $null)
                    
                    # Skip old entries
                    if ($timestamp -lt $startTime) { continue }
                }
                catch {
                    $timestamp = Get-Date
                }
            }
            
            # Create entry object
            $entry = [PSCustomObject]@{
                Time = $timestamp
                Type = if ($line -match 'error') { 'ERROR' } else { 'WARNING' }
                Message = $line.Trim()
                File = $fileName
                Line = $lineNum
            }
            
            # Add to appropriate collection
            if ($entry.Type -eq 'ERROR') {
                $errorsList.Add($entry)
            }
            else {
                $warningsList.Add($entry)
            }
        }
        
        $reader.Close()
        $reader.Dispose()
    }
    catch {
        Write-Warning "Could not read $fileName : $_"
    }
}

$stopwatch.Stop()

# Save to prompts file
$promptsDir = "prompts"
if (![System.IO.Directory]::Exists($promptsDir)) {
    [System.IO.Directory]::CreateDirectory($promptsDir) | Out-Null
}

# Build output file path
$outputFile = Join-Path $promptsDir "prompts.txt"

# Build the output text using StringBuilder for better performance
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("=== CBS Log Scan ===")
[void]$sb.AppendLine("Server: $ServerName")
[void]$sb.AppendLine("Period: $TimePeriod hours")
[void]$sb.AppendLine("Errors: $($errorsList.Count)")
[void]$sb.AppendLine("Warnings: $($warningsList.Count)")
[void]$sb.AppendLine("Time: $($stopwatch.ElapsedMilliseconds)ms")
[void]$sb.AppendLine("Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("====================")
[void]$sb.AppendLine("")

# Add errors section
[void]$sb.AppendLine("--- ERRORS ---")
if ($errorsList.Count -gt 0) {
    $errorCount = 0
    foreach ($errItem in $errorsList) {
        $errorCount++
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Error #$errorCount")
        
        if ($errItem.Time) {
            [void]$sb.AppendLine("Time: $($errItem.Time.ToString('yyyy-MM-dd HH:mm:ss'))")
        } else {
            [void]$sb.AppendLine("Time: N/A")
        }
        
        [void]$sb.AppendLine("File: $($errItem.File) (Line: $($errItem.Line))")
        [void]$sb.AppendLine("Message: $($errItem.Message)")
        [void]$sb.AppendLine("----------------------------------------")
    }
} else {
    [void]$sb.AppendLine("No errors found.")
}

[void]$sb.AppendLine("")

# Add warnings section
[void]$sb.AppendLine("--- WARNINGS ---")
if ($warningsList.Count -gt 0) {
    $warningCount = 0
    foreach ($warnItem in $warningsList) {
        $warningCount++
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Warning #$warningCount")
        
        if ($warnItem.Time) {
            [void]$sb.AppendLine("Time: $($warnItem.Time.ToString('yyyy-MM-dd HH:mm:ss'))")
        } else {
            [void]$sb.AppendLine("Time: N/A")
        }
        
        [void]$sb.AppendLine("File: $($warnItem.File) (Line: $($warnItem.Line))")
        [void]$sb.AppendLine("Message: $($warnItem.Message)")
        [void]$sb.AppendLine("----------------------------------------")
    }
} else {
    [void]$sb.AppendLine("No warnings found.")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("====================")
[void]$sb.AppendLine("")

# Write to file
try {
    $sb.ToString() | Out-File -FilePath $outputFile -Append -Encoding UTF8
    Write-Host "Results successfully saved to: $outputFile" -ForegroundColor Green
} catch {
    Write-Error "Failed to save results to file: $_"
}

# Display results
Write-Host "`n=== Results ===" -ForegroundColor Green
Write-Host "Server      : $ServerName"
Write-Host "Time Period : Last $TimePeriod hours"
Write-Host "Errors      : $($errorsList.Count)" -ForegroundColor $(if($errorsList.Count -gt 0){'Red'}else{'Green'})
Write-Host "Warnings    : $($warningsList.Count)" -ForegroundColor $(if($warningsList.Count -gt 0){'Yellow'}else{'Green'})
Write-Host "Scan Time   : $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "===============`n" -ForegroundColor Green

# Return result object
[PSCustomObject]@{
    Server = $ServerName
    TimePeriod = $TimePeriod
    Errors = $errorsList
    Warnings = $warningsList
    TimeMs = $stopwatch.ElapsedMilliseconds
}
