# Quick inspection
Write-Host "=== FIRST CSV ==="
Get-Content "C:\Temp\work\Book1.csv" -TotalCount 5
Write-Host "`n=== SECOND CSV ==="
Get-Content "C:\Temp\work\dpr.csv" -TotalCount 5

# Show actual column names after import
(Import-Csv "C:\Temp\work\Book1.csv")[0].PSObject.Properties.Name
(Import-Csv "C:\Temp\work\dpr.csv")[0].PSObject.Properties.Name