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
            
            # Skip if no error or 
