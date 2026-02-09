<#
.SYNOPSIS
    Simple high-performance CBS log reader
.PARAMETER TargetServerName
    Server name for logging
.PARAMETER TimePeriod
    Hours to look back from now
.EXAMPLE
    .\Get-CBSLogs-Simple.ps1 -TargetServerName "SERVER01" -TimePeriod 24
#>

param(
    [Parameter(Mandatory)]
    [string]$TargetServerName,
    
    [Parameter(Mandatory)]
    [int]$TimePeriod
)

# CBS log location
$cbsPath = "C:\Windows\Logs\CBS"

# Calculate time filter
$startTime = (Get-Date).AddHours(-$TimePeriod)

# Result collections using .NET for performance
$errors = [System.Collections.Generic.List[object]]::new()
$warnings = [System.Collections.Generic.List[object]]::new()

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
                $errors.Add($entry)
            }
            else {
                $warnings.Add($entry)
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

$promptText = @"
=== CBS Log Scan ===
Server: $TargetServerName
Period: $TimePeriod hours
Errors: $($errors.Count)
Warnings: $($warnings.Count)
Time: $($stopwatch.ElapsedMilliseconds)ms
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
====================

"@

[System.IO.File]::AppendAllText("$promptsDir\prompts.txt", $promptText, [System.Text.Encoding]::UTF8)

# Display results
Write-Host "`n=== Results ===" -ForegroundColor Green
Write-Host "Server      : $TargetServerName"
Write-Host "Time Period : Last $TimePeriod hours"
Write-Host "Errors      : $($errors.Count)" -ForegroundColor $(if($errors.Count -gt 0){'Red'}else{'Green'})
Write-Host "Warnings    : $($warnings.Count)" -ForegroundColor $(if($warnings.Count -gt 0){'Yellow'}else{'Green'})
Write-Host "Scan Time   : $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "===============`n" -ForegroundColor Green

# Return result object
[PSCustomObject]@{
    Server = $TargetServerName
    TimePeriod = $TimePeriod
    Errors = $errors
    Warnings = $warnings
    TimeMs = $stopwatch.ElapsedMilliseconds
}
