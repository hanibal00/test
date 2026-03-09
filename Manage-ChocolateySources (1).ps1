#Requires -Version 5.1
<#
.SYNOPSIS
    Manages Chocolatey sources and upgrades Chocolatey to a specific version.

.DESCRIPTION
    This script performs the following actions:
      1. Adds a new Chocolatey source (win-add-source)
      2. Disables an existing Chocolatey source (win-add-local-source)
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
#  STEP 2 — Disable existing Chocolatey source
# ─────────────────────────────────────────────
Write-Log 'STEP 2: Disabling Chocolatey source "win-add-local-source" ...'

$disableSource = 'win-add-local-source'

try {
    $disableOutput = & choco source disable `
        --name="$disableSource" `
        --yes 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "choco source disable exited with code $LASTEXITCODE. Output: $($disableOutput -join ' ')" -Level WARN
        # Non-fatal: source may already be disabled or may not exist; continue.
    }
    else {
        Write-Log "Source '$disableSource' disabled successfully."
        Write-Log $disableOutput
    }
}
catch {
    Write-Log "Exception while disabling source: $_" -Level WARN
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
