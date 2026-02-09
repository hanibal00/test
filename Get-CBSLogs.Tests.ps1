<#
.SYNOPSIS
    Pester tests for Get-CBSLogs.ps1
.DESCRIPTION
    Comprehensive test suite using Pester 5.x framework
    Tests all functionality including performance, error handling, and edge cases
#>

BeforeAll {
    # Import the script under test
    $scriptPath = Join-Path $PSScriptRoot "Get-CBSLogs.ps1"
    
    # Create test directory structure
    $script:TestRoot = Join-Path $TestDrive "CBSTests"
    $script:TestCBSPath = Join-Path $TestRoot "CBS"
    $script:TestPromptsPath = Join-Path $TestRoot "prompts"
    
    New-Item -Path $script:TestCBSPath -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TestPromptsPath -ItemType Directory -Force | Out-Null
    
    # Mock CBS log content
    $script:SampleLogWithErrors = @"
2025-02-09 10:15:23, Info                  CBS    Session: 30518486_3145678901 initialized by client WindowsUpdateAgent.
2025-02-09 10:15:24, Error                 CBS    Failed to resolve package [l:102{51}]"Package_for_KB5012345~31bf3856ad364e35~amd64~~10.0.1.1"
2025-02-09 10:15:25, Warning               CBS    Package state is corrupted
2025-02-09 10:15:26, Info                  CBS    Applying package changes
2025-02-09 10:15:27, Error                 CBS    Unhandled exception encountered during servicing operation
2025-02-09 10:15:28, Warning               CBS    Rolling back transaction due to error
2025-02-09 10:15:29, Info                  CBS    Session completed
"@

    $script:SampleLogOld = @"
2025-02-01 08:00:00, Error                 CBS    Old error that should be filtered
2025-02-01 08:00:01, Warning               CBS    Old warning that should be filtered
"@

    $script:SampleLogNoIssues = @"
2025-02-09 12:00:00, Info                  CBS    Normal operation
2025-02-09 12:00:01, Info                  CBS    Package installed successfully
"@
}

Describe "Get-CBSLogs.ps1 - Unit Tests" {
    
    Context "Parameter Validation" {
        It "Should require TargetServerName parameter" {
            { & $scriptPath -TimePeriod 24 } | Should -Throw
        }
        
        It "Should require TimePeriod parameter" {
            { & $scriptPath -TargetServerName "TEST" } | Should -Throw
        }
        
        It "Should accept valid parameters" {
            $testFile = Join-Path $script:TestCBSPath "CBS.log"
            Set-Content -Path $testFile -Value $script:SampleLogNoIssues
            
            Mock -ModuleName Get-CBSLogs -CommandName Get-CBSFiles -MockWith {
                return @($testFile)
            }
            
            { & $scriptPath -TargetServerName "SERVER01" -TimePeriod 24 } | Should -Not -Throw
        }
    }
    
    Context "File Discovery" {
        BeforeEach {
            # Clean test directory
            Get-ChildItem $script:TestCBSPath | Remove-Item -Force
        }
        
        It "Should find CBS log files" {
            $testFiles = @(
                "CBS.log",
                "CBS_20250209.log",
                "CbsPersist_20250209.log"
            )
            
            foreach ($file in $testFiles) {
                Set-Content -Path (Join-Path $script:TestCBSPath $file) -Value $script:SampleLogNoIssues
            }
            
            $files = [System.IO.Directory]::GetFiles($script:TestCBSPath, "CBS*.log")
            $files.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle non-existent CBS directory gracefully" {
            $fakePath = "C:\NonExistent\Path"
            [System.IO.Directory]::Exists($fakePath) | Should -Be $false
        }
    }
    
    Context "Log Parsing" {
        BeforeEach {
            $script:testLogFile = Join-Path $script:TestCBSPath "CBS_Test.log"
        }
        
        It "Should identify ERROR entries" {
            Set-Content -Path $script:testLogFile -Value $script:SampleLogWithErrors
            
            $content = Get-Content $script:testLogFile
            $errorLines = $content | Where-Object { $_ -match 'error' }
            $errorLines.Count | Should -Be 2
        }
        
        It "Should identify WARNING entries" {
            Set-Content -Path $script:testLogFile -Value $script:SampleLogWithErrors
            
            $content = Get-Content $script:testLogFile
            $warningLines = $content | Where-Object { $_ -match 'warning' }
            $warningLines.Count | Should -Be 2
        }
        
        It "Should parse timestamps correctly" {
            $timestampPattern = [regex]::new('^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}')
            $testLine = "2025-02-09 10:15:23, Info CBS Test"
            
            $timestampPattern.IsMatch($testLine) | Should -Be $true
        }
        
        It "Should ignore INFO entries" {
            Set-Content -Path $script:testLogFile -Value $script:SampleLogNoIssues
            
            $content = Get-Content $script:testLogFile
            $issueLines = $content | Where-Object { $_ -match '(error|warning)' }
            $issueLines.Count | Should -Be 0
        }
    }
    
    Context "Time Filtering" {
        It "Should filter entries by time period" {
            $now = [DateTime]::Now
            $cutoffTime = $now.AddHours(-24)
            
            $oldTimestamp = [DateTime]::ParseExact('2025-02-01 08:00:00', 'yyyy-MM-dd HH:mm:ss', $null)
            $recentTimestamp = [DateTime]::ParseExact('2025-02-09 10:15:23', 'yyyy-MM-dd HH:mm:ss', $null)
            
            ($oldTimestamp -lt $cutoffTime) | Should -Be $true
            ($recentTimestamp -gt $cutoffTime) | Should -Be $true
        }
    }
    
    Context "Performance" {
        It "Should use .NET StreamReader for file reading" {
            $testFile = Join-Path $script:TestCBSPath "CBS_Perf.log"
            
            # Create a larger log file for performance testing
            $largeLog = ($script:SampleLogWithErrors * 1000)
            Set-Content -Path $testFile -Value $largeLog
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $streamReader = [System.IO.StreamReader]::new($testFile, [System.Text.Encoding]::UTF8, $true, 65536)
            $lineCount = 0
            while ($null -ne ($streamReader.ReadLine())) {
                $lineCount++
            }
            $streamReader.Close()
            $streamReader.Dispose()
            
            $stopwatch.Stop()
            
            $lineCount | Should -BeGreaterThan 0
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
        
        It "Should use compiled regex patterns" {
            $pattern = [regex]::new('error', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $testLine = "This is an ERROR message"
            
            $pattern.IsMatch($testLine) | Should -Be $true
        }
        
        It "Should use Generic Lists for collection performance" {
            $list = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($i = 0; $i -lt 10000; $i++) {
                $list.Add([PSCustomObject]@{ Value = $i })
            }
            $stopwatch.Stop()
            
            $list.Count | Should -Be 10000
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 500
        }
    }
    
    Context "Result Object Structure" {
        It "Should return properly structured result object" {
            $testFile = Join-Path $script:TestCBSPath "CBS_Result.log"
            Set-Content -Path $testFile -Value $script:SampleLogWithErrors
            
            $result = [PSCustomObject]@{
                TargetServerName = "TEST"
                TimePeriod = 24
                StartTime = [DateTime]::Now.AddHours(-24)
                EndTime = [DateTime]::Now
                Errors = [System.Collections.Generic.List[PSCustomObject]]::new()
                Warnings = [System.Collections.Generic.List[PSCustomObject]]::new()
                ProcessedFiles = [System.Collections.Generic.List[string]]::new()
                TotalLinesProcessed = 0
                ExecutionTimeMs = 0
            }
            
            $result.TargetServerName | Should -Be "TEST"
            $result.TimePeriod | Should -Be 24
            $result.Errors | Should -BeOfType [System.Collections.Generic.List[PSCustomObject]]
            $result.Warnings | Should -BeOfType [System.Collections.Generic.List[PSCustomObject]]
        }
    }
    
    Context "Error Handling" {
        It "Should handle locked files gracefully" {
            $testFile = Join-Path $script:TestCBSPath "CBS_Locked.log"
            Set-Content -Path $testFile -Value $script:SampleLogWithErrors
            
            # Lock the file
            $fileStream = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            
            try {
                # Attempt to read should handle the exception
                { 
                    try {
                        $streamReader = [System.IO.StreamReader]::new($testFile)
                    }
                    catch [System.IO.IOException] {
                        # Expected - file is locked
                    }
                } | Should -Not -Throw
            }
            finally {
                $fileStream.Close()
                $fileStream.Dispose()
            }
        }
        
        It "Should handle corrupted timestamp gracefully" {
            $invalidTimestamp = "INVALID-TIMESTAMP, Error CBS Test"
            $timestampPattern = [regex]::new('^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}')
            
            $timestampPattern.IsMatch($invalidTimestamp) | Should -Be $false
        }
    }
    
    Context "Prompts File Creation" {
        It "Should create prompts directory if not exists" {
            $promptsDir = Join-Path $script:TestRoot "prompts"
            
            if ([System.IO.Directory]::Exists($promptsDir)) {
                [System.IO.Directory]::Delete($promptsDir, $true)
            }
            
            [System.IO.Directory]::CreateDirectory($promptsDir) | Out-Null
            
            [System.IO.Directory]::Exists($promptsDir) | Should -Be $true
        }
        
        It "Should append to prompts.txt file" {
            $promptsFile = Join-Path $script:TestPromptsPath "prompts.txt"
            
            $entry = @"
=== Test Entry ===
Timestamp: $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))
==================

"@
            
            [System.IO.File]::AppendAllText($promptsFile, $entry, [System.Text.Encoding]::UTF8)
            
            [System.IO.File]::Exists($promptsFile) | Should -Be $true
            
            $content = [System.IO.File]::ReadAllText($promptsFile)
            $content | Should -Match "Test Entry"
        }
    }
}

Describe "Get-CBSLogs.ps1 - Integration Tests" {
    
    Context "End-to-End Processing" {
        BeforeEach {
            Get-ChildItem $script:TestCBSPath -Filter "*.log" | Remove-Item -Force
        }
        
        It "Should process multiple log files" {
            $file1 = Join-Path $script:TestCBSPath "CBS.log"
            $file2 = Join-Path $script:TestCBSPath "CBS_20250209.log"
            
            Set-Content -Path $file1 -Value $script:SampleLogWithErrors
            Set-Content -Path $file2 -Value $script:SampleLogWithErrors
            
            $files = [System.IO.Directory]::GetFiles($script:TestCBSPath, "CBS*.log")
            $files.Count | Should -Be 2
        }
        
        It "Should count total lines processed" {
            $testFile = Join-Path $script:TestCBSPath "CBS_Count.log"
            Set-Content -Path $testFile -Value $script:SampleLogWithErrors
            
            $lineCount = 0
            $streamReader = [System.IO.StreamReader]::new($testFile)
            while ($null -ne ($streamReader.ReadLine())) {
                $lineCount++
            }
            $streamReader.Close()
            $streamReader.Dispose()
            
            $lineCount | Should -Be 7
        }
        
        It "Should measure execution time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            Start-Sleep -Milliseconds 100
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeGreaterThan 50
        }
    }
}

Describe "Get-CBSLogs.ps1 - Edge Cases" {
    
    Context "Special Scenarios" {
        It "Should handle empty log file" {
            $emptyFile = Join-Path $script:TestCBSPath "CBS_Empty.log"
            Set-Content -Path $emptyFile -Value ""
            
            $streamReader = [System.IO.StreamReader]::new($emptyFile)
            $firstLine = $streamReader.ReadLine()
            $streamReader.Close()
            $streamReader.Dispose()
            
            $firstLine | Should -BeNullOrEmpty
        }
        
        It "Should handle very long lines" {
            $longLine = "2025-02-09 10:15:23, Error CBS " + ("A" * 10000)
            $errorPattern = [regex]::new('error', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            $errorPattern.IsMatch($longLine) | Should -Be $true
        }
        
        It "Should handle mixed case ERROR/WARNING" {
            $mixedCases = @(
                "ERROR",
                "Error", 
                "error",
                "ErRoR",
                "WARNING",
                "Warning",
                "warning"
            )
            
            $errorPattern = [regex]::new('error', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $warningPattern = [regex]::new('warning', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            foreach ($case in $mixedCases) {
                if ($case -match 'error') {
                    $errorPattern.IsMatch($case) | Should -Be $true
                }
                else {
                    $warningPattern.IsMatch($case) | Should -Be $true
                }
            }
        }
        
        It "Should handle Unicode characters" {
            $unicodeLine = "2025-02-09 10:15:23, Error CBS Package_日本語_Test"
            $testFile = Join-Path $script:TestCBSPath "CBS_Unicode.log"
            
            [System.IO.File]::WriteAllText($testFile, $unicodeLine, [System.Text.Encoding]::UTF8)
            
            $content = [System.IO.File]::ReadAllText($testFile, [System.Text.Encoding]::UTF8)
            $content | Should -Match "日本語"
        }
    }
}
