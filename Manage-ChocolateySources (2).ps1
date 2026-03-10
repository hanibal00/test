#Requires -Version 5.1
<#
.SYNOPSIS
    Manages Chocolatey sources and upgrades Chocolatey to a specific version.

.DESCRIPTION
    This script performs the following actions:
      1. Adds a new Chocolatey source (win-add-source)
      2. Disables ALL currently enabled Chocolatey sources (except the one just added)
      3. Upgrades Chocolatey to version 2.5.1.0

.NOTES
    Requires: PowerShell 5.1, Chocolatey installed, Administrator privileges
#>

# ─────────────────────────────────────────────
#  Log file setup
# ─────────────────────────────────────────────
$LogDir  = 'C:\temp\ChocolateySources'
$LogFile = Join-Path $LogDir ("ChocolateySources_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ─────────────────────────────────────────────
#  Helper: Write timestamped log messages
# ─────────────────────────────────────────────
function Write-Log {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Message,

        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    # Safely coerce any type (array, ErrorRecord, object) to a single string
    $text = if ($Message -is [System.Array]) {
        ($Message | ForEach-Object { "$_" }) -join ' '
    } else {
        "$Message"
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colour = switch ($Level) {
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red'    }
        default { 'Cyan'   }
    }

    $line = "[$timestamp] [$Level] $text"
    Write-Host $line -ForegroundColor $colour
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
}

# ─────────────────────────────────────────────
#  Guard: Must run as Administrator
# ─────────────────────────────────────────────
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log 'This script must be run as Administrator. Exiting.' -Level ERROR
    exit 1
}

# ─────────────────────────────────────────────
#  Guard: Chocolatey must be installed
# ─────────────────────────────────────────────
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log 'Chocolatey (choco) was not found in PATH. Please install Chocolatey first. Exiting.' -Level ERROR
    exit 1
}

Write-Log "Log file: $LogFile"
Write-Log "Chocolatey found: $(choco --version)"

# ─────────────────────────────────────────────
#  STEP 1 — Add new Chocolatey source
# ─────────────────────────────────────────────
Write-Log 'STEP 1: Adding Chocolatey source "win-add-source" ...'

$sourceName = 'win-add-source'
$sourceUrl  = 'https://contoso.com/api/win-add-source-release'
$sourceUser = 'admin'
$sourcePass = 'Padmin123'

try {
    $addOutput = & choco source add `
        --name="$sourceName" `
        --source="$sourceUrl" `
        --user="$sourceUser" `
        --password="$sourcePass" `
        --yes 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "choco source add exited with code $LASTEXITCODE. Output: $($addOutput -join ' ')" -Level ERROR
        exit 1
    }

    Write-Log "Source '$sourceName' added successfully."
    Write-Log $addOutput
}
catch {
    Write-Log "Exception while adding source: $_" -Level ERROR
    exit 1
}

# ─────────────────────────────────────────────
#  STEP 2 — Disable ALL currently enabled sources
#           (except the one we just added)
# ─────────────────────────────────────────────
Write-Log 'STEP 2: Detecting and disabling all currently enabled Chocolatey sources ...'

try {
    # Parse enabled sources from: choco source list
    # Output format per line: "sourcename - https://url | Priority X"
    # Disabled sources contain the word "Disabled"
    $sourceListRaw = & choco source list 2>&1
    $enabledSources = $sourceListRaw | ForEach-Object {
        $line = "$_".Trim()
        # Skip blank lines, headers, and disabled entries
        if ($line -and $line -notmatch '^\[' -and $line -notmatch 'Disabled' -and $line -match '^(.+?)\s*[-|]') {
            $name = $Matches[1].Trim()
            # Skip the source we just added
            if ($name -and $name -ne $sourceName) {
                $name
            }
        }
    } | Where-Object { $_ }

    if (-not $enabledSources) {
        Write-Log 'No additional enabled sources found to disable.'
    }
    else {
        foreach ($src in $enabledSources) {
            Write-Log "Disabling source: '$src' ..."
            try {
                $disableOutput = & choco source disable --name="$src" --yes 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "choco source disable '$src' exited with code $LASTEXITCODE. Output: $($disableOutput -join ' ')" -Level WARN
                }
                else {
                    Write-Log "Source '$src' disabled successfully."
                }
            }
            catch {
                Write-Log "Exception while disabling source '$src': $_" -Level WARN
                # Non-fatal; continue to next source.
            }
        }
    }
}
catch {
    Write-Log "Exception while listing sources: $_" -Level WARN
    # Non-fatal; continue to upgrade step.
}

# ─────────────────────────────────────────────
#  STEP 3 — Upgrade Chocolatey to version 2.5.1.0
# ─────────────────────────────────────────────
Write-Log 'STEP 3: Upgrading Chocolatey to version 2.5.1.0 ...'

$chocoTargetVersion = '2.5.1.0'

try {
    $upgradeOutput = & choco upgrade chocolatey `
        --version="$chocoTargetVersion" `
        --source="$sourceName" `
        --yes 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "choco upgrade exited with code $LASTEXITCODE. Output: $($upgradeOutput -join ' ')" -Level ERROR
        exit 1
    }

    Write-Log "Chocolatey upgraded to version $chocoTargetVersion successfully."
    Write-Log $upgradeOutput
}
catch {
    Write-Log "Exception during Chocolatey upgrade: $_" -Level ERROR
    exit 1
}

# ─────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────
Write-Log 'All steps completed successfully.'
Write-Log "Full log saved to: $LogFile"
