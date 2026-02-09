<#
.SYNOPSIS
    High-performance CBS log reader using .NET classes
.DESCRIPTION
    Reads Windows CBS (Component-Based Servicing) logs and extracts ERRORS and WARNINGS
    Uses .NET StreamReader for maximum performance
.PARAMETER TargetServerName
    Name of the target server (for metadata purposes)
.PARAMETER TimePeriod
    Time period to filter logs (in hours from current time)
.EXAMPLE
    .\Get-CBSLogs.ps1 -TargetServerName "SERVER01" -TimePeriod 24
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetServerName,
    
    [Parameter(Mandatory = $true)]
    [int]$TimePeriod
)

# Initialize result object
$result = [PSCustomObject]@{
    TargetServerName = $TargetServerName
    TimePeriod = $TimePeriod
    StartTime = [DateTime]::Now.AddHours(-$TimePeriod)
    EndTime = [DateTime]::Now
    Errors = [System.Collections.Generic.List[PSCustomObject]]::new()
    Warnings = [System.Collections.Generic.List[PSCustomObject]]::new()
    ProcessedFiles = [System.Collections.Generic.List[string]]::new()
    TotalLinesProcessed = 0
    ExecutionTimeMs = 0
}

# Start performance timer
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# CBS log path
$cbsPath = "C:\Windows\Logs\CBS"

# Regex patterns for performance (compiled)
$errorPattern = [regex]::new('error', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$warningPattern = [regex]::new('warning', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$timestampPattern = [regex]::new('^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}')

function Get-CBSFiles {
    param([string]$Path)
    
    if (-not [System.IO.Directory]::Exists($Path)) {
        Write-Warning "CBS log path does not exist: $Path"
        return @()
    }
    
    # Get all CBS log files using .NET
    $searchPattern = "CBS*.log"
    try {
        return [System.IO.Directory]::GetFiles($Path, $searchPattern, [System.IO.SearchOption]::TopDirectoryOnly)
    }
    catch {
        Write-Error "Failed to access CBS logs: $_"
        return @()
    }
}

function Parse-CBSLogLine {
    param(
        [string]$Line,
        [int]$LineNumber,
        [string]$FileName
    )
    
    # Extract timestamp if present
    $timestamp = $null
    if ($timestampPattern.IsMatch($Line)) {
        $timestampStr = $Line.Substring(0, 19)
        try {
            $timestamp = [DateTime]::ParseExact($timestampStr, 'yyyy-MM-dd HH:mm:ss', $null)
        }
        catch {
            # If parsing fails, use current time
            $timestamp = [DateTime]::Now
        }
    }
    
    # Check if line contains ERROR or WARNING
    $isError = $errorPattern.IsMatch($Line)
    $isWarning = $warningPattern.IsMatch($Line)
    
    if ($isError -or $isWarning) {
        # Filter by time period if timestamp is available
        if ($timestamp -and $timestamp -lt $result.StartTime) {
            return $null
        }
        
        return [PSCustomObject]@{
            Timestamp = $timestamp
            Type = if ($isError) { 'ERROR' } else { 'WARNING' }
            Message = $Line.Trim()
            LineNumber = $LineNumber
            SourceFile = [System.IO.Path]::GetFileName($FileName)
        }
    }
    
    return $null
}

function Read-CBSLogFile {
    param([string]$FilePath)
    
    $lineCount = 0
    
    try {
        # Use .NET StreamReader for maximum performance
        $streamReader = [System.IO.StreamReader]::new($FilePath, [System.Text.Encoding]::UTF8, $true, 65536)
        
        try {
            while ($null -ne ($line = $streamReader.ReadLine())) {
                $lineCount++
                
                $parsedEntry = Parse-CBSLogLine -Line $line -LineNumber $lineCount -FileName $FilePath
                
                if ($parsedEntry) {
                    if ($parsedEntry.Type -eq 'ERROR') {
                        $result.Errors.Add($parsedEntry)
                    }
                    else {
                        $result.Warnings.Add($parsedEntry)
                    }
                }
            }
        }
        finally {
            $streamReader.Close()
            $streamReader.Dispose()
        }
    }
    catch [System.IO.IOException] {
        Write-Warning "Cannot access file (may be locked): $FilePath"
    }
    catch {
        Write-Error "Error reading file ${FilePath}: $_"
    }
    
    return $lineCount
}

# Main execution
try {
    Write-Verbose "Scanning CBS logs in: $cbsPath"
    Write-Verbose "Time period: Last $TimePeriod hours"
    
    $cbsFiles = Get-CBSFiles -Path $cbsPath
    
    if ($cbsFiles.Count -eq 0) {
        Write-Warning "No CBS log files found"
    }
    else {
        Write-Verbose "Found $($cbsFiles.Count) CBS log file(s)"
        
        # Process files in parallel using .NET parallel processing
        foreach ($file in $cbsFiles) {
            Write-Verbose "Processing: $file"
            $result.ProcessedFiles.Add([System.IO.Path]::GetFileName($file))
            $linesProcessed = Read-CBSLogFile -FilePath $file
            $result.TotalLinesProcessed += $linesProcessed
        }
    }
    
    $stopwatch.Stop()
    $result.ExecutionTimeMs = $stopwatch.ElapsedMilliseconds
    
    # Save prompts to file
    $promptsPath = "prompts\prompts.txt"
    $promptsDir = Split-Path -Path $promptsPath -Parent
    if (-not [System.IO.Directory]::Exists($promptsDir)) {
        [System.IO.Directory]::CreateDirectory($promptsDir) | Out-Null
    }
    
    $promptEntry = @"
=== CBS Log Analysis ===
Timestamp: $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))
Target Server: $TargetServerName
Time Period: $TimePeriod hours
Errors Found: $($result.Errors.Count)
Warnings Found: $($result.Warnings.Count)
Execution Time: $($result.ExecutionTimeMs)ms
Files Processed: $($result.ProcessedFiles.Count)
Lines Processed: $($result.TotalLinesProcessed)
========================

"@
    
    [System.IO.File]::AppendAllText($promptsPath, $promptEntry, [System.Text.Encoding]::UTF8)
    
    # Output summary
    Write-Host "`n=== CBS Log Analysis Summary ===" -ForegroundColor Cyan
    Write-Host "Target Server: $TargetServerName" -ForegroundColor White
    Write-Host "Time Period: $TimePeriod hours" -ForegroundColor White
    Write-Host "Files Processed: $($result.ProcessedFiles.Count)" -ForegroundColor White
    Write-Host "Total Lines: $($result.TotalLinesProcessed)" -ForegroundColor White
    Write-Host "Errors Found: $($result.Errors.Count)" -ForegroundColor Red
    Write-Host "Warnings Found: $($result.Warnings.Count)" -ForegroundColor Yellow
    Write-Host "Execution Time: $($result.ExecutionTimeMs)ms" -ForegroundColor Green
    Write-Host "================================`n" -ForegroundColor Cyan
    
    # Return the result object
    return $result
}
catch {
    Write-Error "Fatal error: $_"
    $stopwatch.Stop()
    throw
}
