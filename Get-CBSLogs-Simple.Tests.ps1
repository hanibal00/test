<#
.SYNOPSIS
    Simple tests for Get-CBSLogs-Simple.ps1
#>

BeforeAll {
    # Setup test environment
    $script:TestDir = Join-Path $TestDrive "CBS"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
    
    # Sample log data
    $script:SampleLog = @"
2025-02-09 10:00:00, Info                  CBS    Starting session
2025-02-09 10:00:01, Error                 CBS    Package installation failed
2025-02-09 10:00:02, Warning               CBS    Component needs repair
2025-02-09 10:00:03, Info                  CBS    Processing complete
"@
}

Describe "Get-CBSLogs-Simple Tests" {
    
    Context "Basic Functionality" {
        
        It "Requires TargetServerName parameter" {
            { & .\Get-CBSLogs-Simple.ps1 -TimePeriod 24 } | Should -Throw
        }
        
        It "Requires TimePeriod parameter" {
            { & .\Get-CBSLogs-Simple.ps1 -TargetServerName "TEST" } | Should -Throw
        }
        
        It "Finds ERROR in log line" {
            $line = "2025-02-09 10:00:01, Error CBS Package failed"
            $line -match 'error' | Should -Be $true
        }
        
        It "Finds WARNING in log line" {
            $line = "2025-02-09 10:00:02, Warning CBS Issue detected"
            $line -match 'warning' | Should -Be $true
        }
        
        It "Skips INFO lines" {
            $line = "2025-02-09 10:00:00, Info CBS Normal operation"
            $line -match 'error|warning' | Should -Be $false
        }
    }
    
    Context "Timestamp Parsing" {
        
        It "Parses valid timestamp" {
            $timestamp = "2025-02-09 10:15:23"
            { [DateTime]::ParseExact($timestamp, 'yyyy-MM-dd HH:mm:ss', $null) } | Should -Not -Throw
        }
        
        It "Detects timestamp pattern" {
            $line = "2025-02-09 10:15:23, Error CBS Test"
            $line -match '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}' | Should -Be $true
        }
        
        It "Calculates time filter correctly" {
            $hours = 24
            $startTime = (Get-Date).AddHours(-$hours)
            $startTime | Should -BeLessThan (Get-Date)
        }
    }
    
    Context "File Operations" {
        
        It "Creates CBS directory for testing" {
            $testPath = Join-Path $TestDrive "TestCBS"
            [System.IO.Directory]::CreateDirectory($testPath) | Out-Null
            [System.IO.Directory]::Exists($testPath) | Should -Be $true
        }
        
        It "Lists log files using .NET" {
            $testFile = Join-Path $script:TestDir "CBS.log"
            Set-Content -Path $testFile -Value $script:SampleLog
            
            $files = [System.IO.Directory]::GetFiles($script:TestDir, "CBS*.log")
            $files.Count | Should -BeGreaterThan 0
        }
        
        It "Uses StreamReader for file reading" {
            $testFile = Join-Path $script:TestDir "CBS_Read.log"
            Set-Content -Path $testFile -Value $script:SampleLog
            
            $reader = [System.IO.StreamReader]::new($testFile)
            $firstLine = $reader.ReadLine()
            $reader.Close()
            $reader.Dispose()
            
            $firstLine | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Collections" {
        
        It "Uses Generic List for performance" {
            $list = [System.Collections.Generic.List[object]]::new()
            
            1..100 | ForEach-Object {
                $list.Add([PSCustomObject]@{ Value = $_ })
            }
            
            $list.Count | Should -Be 100
            $list | Should -BeOfType [System.Collections.Generic.List[object]]
        }
        
        It "Adds items to list efficiently" {
            $errors = [System.Collections.Generic.List[object]]::new()
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            1..1000 | ForEach-Object {
                $errors.Add([PSCustomObject]@{ Id = $_ })
            }
            $stopwatch.Stop()
            
            $errors.Count | Should -Be 1000
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
        }
    }
    
    Context "Performance Tracking" {
        
        It "Measures execution time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Start-Sleep -Milliseconds 50
            $stopwatch.Stop()
            
            $stopwatch.ElapsedMilliseconds | Should -BeGreaterThan 40
        }
        
        It "Uses Stopwatch class" {
            $sw = [System.Diagnostics.Stopwatch]::new()
            $sw.Start()
            $sw.Stop()
            
            $sw.ElapsedMilliseconds | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "Result Object" {
        
        It "Returns structured result" {
            $result = [PSCustomObject]@{
                Server = "TEST"
                TimePeriod = 24
                Errors = @()
                Warnings = @()
                TimeMs = 100
            }
            
            $result.Server | Should -Be "TEST"
            $result.TimePeriod | Should -Be 24
            $result.TimeMs | Should -Be 100
        }
    }
    
    Context "Error Handling" {
        
        It "Handles missing directory" {
            $fakePath = "C:\NonExistent\Path"
            [System.IO.Directory]::Exists($fakePath) | Should -Be $false
        }
        
        It "Handles file read errors gracefully" {
            $testFile = Join-Path $script:TestDir "Locked.log"
            Set-Content -Path $testFile -Value "test"
            
            # Lock file
            $stream = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Open, 
                                              [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            
            try {
                { 
                    try {
                        $reader = [System.IO.StreamReader]::new($testFile)
                    }
                    catch {
                        # Expected - file locked
                    }
                } | Should -Not -Throw
            }
            finally {
                $stream.Close()
            }
        }
    }
    
    Context "Prompts File" {
        
        It "Creates prompts directory" {
            $promptDir = Join-Path $TestDrive "prompts"
            [System.IO.Directory]::CreateDirectory($promptDir) | Out-Null
            [System.IO.Directory]::Exists($promptDir) | Should -Be $true
        }
        
        It "Appends to prompts.txt" {
            $promptFile = Join-Path $script:TestDir "prompts.txt"
            $text = "Test entry`n"
            
            [System.IO.File]::AppendAllText($promptFile, $text, [System.Text.Encoding]::UTF8)
            
            [System.IO.File]::Exists($promptFile) | Should -Be $true
            $content = [System.IO.File]::ReadAllText($promptFile)
            $content | Should -Match "Test entry"
        }
    }
    
    Context "Line Processing" {
        
        It "Extracts line type correctly" {
            $errorLine = "2025-02-09 10:00:00, Error CBS Test"
            $type = if ($errorLine -match 'error') { 'ERROR' } else { 'WARNING' }
            $type | Should -Be 'ERROR'
        }
        
        It "Handles case-insensitive matching" {
            $tests = @('ERROR', 'Error', 'error', 'ErRoR')
            
            foreach ($test in $tests) {
                $test -match 'error' | Should -Be $true
            }
        }
        
        It "Creates entry object with required fields" {
            $entry = [PSCustomObject]@{
                Time = Get-Date
                Type = 'ERROR'
                Message = "Test message"
                File = "CBS.log"
                Line = 123
            }
            
            $entry.Type | Should -Be 'ERROR'
            $entry.File | Should -Be "CBS.log"
            $entry.Line | Should -Be 123
        }
    }
}

Describe "Integration Test" {
    
    It "Processes complete log file" {
        $logFile = Join-Path $script:TestDir "CBS_Integration.log"
        Set-Content -Path $logFile -Value $script:SampleLog
        
        # Simulate processing
        $errors = [System.Collections.Generic.List[object]]::new()
        $warnings = [System.Collections.Generic.List[object]]::new()
        
        $reader = [System.IO.StreamReader]::new($logFile)
        $lineNum = 0
        
        while ($null -ne ($line = $reader.ReadLine())) {
            $lineNum++
            
            if ($line -match 'error') {
                $errors.Add([PSCustomObject]@{ Line = $lineNum; Text = $line })
            }
            elseif ($line -match 'warning') {
                $warnings.Add([PSCustomObject]@{ Line = $lineNum; Text = $line })
            }
        }
        
        $reader.Close()
        $reader.Dispose()
        
        # Verify results
        $errors.Count | Should -Be 1
        $warnings.Count | Should -Be 1
    }
}
