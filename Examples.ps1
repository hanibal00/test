<#
.SYNOPSIS
    Example usage scenarios for Get-CBSLogs.ps1
.DESCRIPTION
    Demonstrates various ways to use the CBS log reader
#>

# Example 1: Basic Usage
Write-Host "`n=== Example 1: Basic Usage ===" -ForegroundColor Cyan
$result = .\Get-CBSLogs.ps1 -TargetServerName "LOCALHOST" -TimePeriod 24

Write-Host "Total Errors: $($result.Errors.Count)"
Write-Host "Total Warnings: $($result.Warnings.Count)"
Write-Host "Execution Time: $($result.ExecutionTimeMs)ms"

# Example 2: Get Only Critical Errors
Write-Host "`n=== Example 2: Filter Critical Errors ===" -ForegroundColor Cyan
$criticalErrors = $result.Errors | Where-Object { 
    $_.Message -match 'Failed|Critical|Fatal|Exception' 
}

if ($criticalErrors.Count -gt 0) {
    Write-Host "Found $($criticalErrors.Count) critical errors:" -ForegroundColor Red
    $criticalErrors | Format-Table Timestamp, Type, SourceFile -AutoSize
}
else {
    Write-Host "No critical errors found" -ForegroundColor Green
}

# Example 3: Export to CSV
Write-Host "`n=== Example 3: Export to CSV ===" -ForegroundColor Cyan
if ($result.Errors.Count -gt 0) {
    $result.Errors | Export-Csv -Path "CBS_Errors.csv" -NoTypeInformation
    Write-Host "Exported $($result.Errors.Count) errors to CBS_Errors.csv" -ForegroundColor Green
}

# Example 4: Group Errors by Source File
Write-Host "`n=== Example 4: Group by Source File ===" -ForegroundColor Cyan
$grouped = $result.Errors | Group-Object SourceFile
$grouped | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) errors" -ForegroundColor Yellow
}

# Example 5: Time-based Analysis
Write-Host "`n=== Example 5: Errors by Hour ===" -ForegroundColor Cyan
$errorsByHour = $result.Errors | 
    Where-Object { $null -ne $_.Timestamp } |
    Group-Object { $_.Timestamp.Hour } |
    Sort-Object Name

foreach ($hour in $errorsByHour) {
    Write-Host "Hour $($hour.Name):00 - $($hour.Count) errors"
}

# Example 6: Create HTML Report
Write-Host "`n=== Example 6: Generate HTML Report ===" -ForegroundColor Cyan

$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>CBS Log Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .error { color: #e74c3c; }
        .warning { color: #f39c12; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th { background: #34495e; color: white; padding: 10px; text-align: left; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
    </style>
</head>
<body>
    <h1>CBS Log Analysis Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Server:</strong> $($result.TargetServerName)</p>
        <p><strong>Time Period:</strong> Last $($result.TimePeriod) hours</p>
        <p><strong>Analysis Time:</strong> $($result.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
        <p class="error"><strong>Errors Found:</strong> $($result.Errors.Count)</p>
        <p class="warning"><strong>Warnings Found:</strong> $($result.Warnings.Count)</p>
        <p><strong>Files Processed:</strong> $($result.ProcessedFiles.Count)</p>
        <p><strong>Lines Processed:</strong> $($result.TotalLinesProcessed.ToString('N0'))</p>
        <p><strong>Execution Time:</strong> $($result.ExecutionTimeMs)ms</p>
    </div>
    
    <h2>Errors</h2>
    $($result.Errors | Select-Object Timestamp, Type, SourceFile, LineNumber, @{N='Message';E={$_.Message.Substring(0, [Math]::Min(100, $_.Message.Length))}} | ConvertTo-Html -Fragment)
    
    <h2>Warnings</h2>
    $($result.Warnings | Select-Object Timestamp, Type, SourceFile, LineNumber, @{N='Message';E={$_.Message.Substring(0, [Math]::Min(100, $_.Message.Length))}} | ConvertTo-Html -Fragment)
</body>
</html>
"@

$htmlReport | Out-File -FilePath "CBS_Report.html" -Encoding UTF8
Write-Host "HTML report saved to CBS_Report.html" -ForegroundColor Green

# Example 7: Performance Comparison
Write-Host "`n=== Example 7: Performance Metrics ===" -ForegroundColor Cyan

$linesPerSecond = if ($result.ExecutionTimeMs -gt 0) {
    [math]::Round($result.TotalLinesProcessed / ($result.ExecutionTimeMs / 1000), 0)
} else {
    0
}

Write-Host "Lines per second: $($linesPerSecond.ToString('N0'))" -ForegroundColor Green
Write-Host "Average time per file: $([math]::Round($result.ExecutionTimeMs / [Math]::Max(1, $result.ProcessedFiles.Count), 2))ms" -ForegroundColor Green

# Example 8: Find Patterns in Errors
Write-Host "`n=== Example 8: Common Error Patterns ===" -ForegroundColor Cyan

$patterns = @{
    'Package' = 'package'
    'Access Denied' = 'access.*denied'
    'Failed' = '\bfailed\b'
    'Timeout' = 'timeout'
    'Corrupt' = 'corrupt'
}

foreach ($pattern in $patterns.GetEnumerator()) {
    $matches = $result.Errors | Where-Object { $_.Message -match $pattern.Value }
    if ($matches.Count -gt 0) {
        Write-Host "$($pattern.Key): $($matches.Count) occurrences" -ForegroundColor Yellow
    }
}

# Example 9: Multi-Server Analysis (Simulated)
Write-Host "`n=== Example 9: Multi-Server Analysis ===" -ForegroundColor Cyan

$servers = @("SERVER01", "SERVER02", "SERVER03")
$allResults = @()

foreach ($server in $servers) {
    Write-Host "Processing $server..." -NoNewline
    try {
        # In real scenario, you might use remoting here
        $serverResult = .\Get-CBSLogs.ps1 -TargetServerName $server -TimePeriod 24 -ErrorAction Stop
        $allResults += $serverResult
        Write-Host " Done" -ForegroundColor Green
    }
    catch {
        Write-Host " Failed: $_" -ForegroundColor Red
    }
}

if ($allResults.Count -gt 0) {
    $totalErrors = ($allResults | Measure-Object -Property @{E={$_.Errors.Count}} -Sum).Sum
    $totalWarnings = ($allResults | Measure-Object -Property @{E={$_.Warnings.Count}} -Sum).Sum
    
    Write-Host "`nTotal across all servers:"
    Write-Host "  Errors: $totalErrors"
    Write-Host "  Warnings: $totalWarnings"
}

# Example 10: Custom Filtering and Alerting
Write-Host "`n=== Example 10: Custom Alerting ===" -ForegroundColor Cyan

$thresholds = @{
    ErrorCount = 10
    WarningCount = 20
}

if ($result.Errors.Count -gt $thresholds.ErrorCount) {
    Write-Host "⚠ ALERT: Error count ($($result.Errors.Count)) exceeds threshold ($($thresholds.ErrorCount))" -ForegroundColor Red
}

if ($result.Warnings.Count -gt $thresholds.WarningCount) {
    Write-Host "⚠ ALERT: Warning count ($($result.Warnings.Count)) exceeds threshold ($($thresholds.WarningCount))" -ForegroundColor Yellow
}

# Example 11: JSON Export for Integration
Write-Host "`n=== Example 11: Export to JSON ===" -ForegroundColor Cyan

$jsonOutput = @{
    Server = $result.TargetServerName
    Timestamp = $result.EndTime.ToString('o')
    TimePeriodHours = $result.TimePeriod
    ErrorCount = $result.Errors.Count
    WarningCount = $result.Warnings.Count
    ExecutionTimeMs = $result.ExecutionTimeMs
    Errors = $result.Errors | Select-Object -First 10 | ForEach-Object {
        @{
            Timestamp = $_.Timestamp.ToString('o')
            Type = $_.Type
            Message = $_.Message
            SourceFile = $_.SourceFile
        }
    }
} | ConvertTo-Json -Depth 5

$jsonOutput | Out-File -FilePath "CBS_Results.json" -Encoding UTF8
Write-Host "JSON results saved to CBS_Results.json" -ForegroundColor Green

# Example 12: Quick Health Check
Write-Host "`n=== Example 12: Quick Health Check ===" -ForegroundColor Cyan

function Get-CBSHealthStatus {
    param($Result)
    
    $score = 100
    
    # Deduct points for errors
    $score -= ($Result.Errors.Count * 2)
    
    # Deduct points for warnings
    $score -= ($Result.Warnings.Count * 1)
    
    $score = [Math]::Max(0, $score)
    
    $status = switch ($score) {
        {$_ -ge 90} { "Excellent"; break }
        {$_ -ge 70} { "Good"; break }
        {$_ -ge 50} { "Fair"; break }
        {$_ -ge 30} { "Poor"; break }
        default { "Critical" }
    }
    
    return @{
        Score = $score
        Status = $status
        Color = switch ($status) {
            "Excellent" { "Green" }
            "Good" { "Cyan" }
            "Fair" { "Yellow" }
            "Poor" { "Magenta" }
            "Critical" { "Red" }
        }
    }
}

$health = Get-CBSHealthStatus -Result $result
Write-Host "CBS Health Score: $($health.Score)/100 - Status: $($health.Status)" -ForegroundColor $health.Color

Write-Host "`n=== Examples Complete ===" -ForegroundColor Cyan
Write-Host "Check the generated files:" -ForegroundColor White
Write-Host "  - CBS_Errors.csv" -ForegroundColor Gray
Write-Host "  - CBS_Report.html" -ForegroundColor Gray
Write-Host "  - CBS_Results.json" -ForegroundColor Gray
Write-Host "  - prompts\prompts.txt" -ForegroundColor Gray
