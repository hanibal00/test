#Requires -Version 5.1
#Requires -RunAsAdministrator

$TargetDir   = "C:\ProgramData\B\IRT\winlog"
$TargetFile  = Join-Path $TargetDir "winlog.yml"
$ServiceName = "winlog"
$BackupFile  = Join-Path $TargetDir ("winlog.yml.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$LogFile     = "C:\temp\replacefile.txt"
$NewConfigPath = Join-Path $PSScriptRoot "winlog.yml"

# ── Logging function ─────────────────────────────────────────────────────────
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"

    if (-not (Test-Path "C:\temp")) {
        New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
    }

    Add-Content -Path $LogFile -Value $entry

    switch ($Level) {
        "WARN"  { Write-Host $entry -ForegroundColor Yellow }
        "ERROR" { Write-Host $entry -ForegroundColor Red    }
        default { Write-Host $entry }
    }
}

# ── Script start ─────────────────────────────────────────────────────────────
Write-Log "===== winlog.yml replacement started ====="
Write-Log "Source : $NewConfigPath"
Write-Log "Target : $TargetFile"

# ── 1. Validate source file ──────────────────────────────────────────────────
if (-not (Test-Path -Path $NewConfigPath -PathType Leaf)) {
    Write-Log "Source winlog.yml not found in script folder: $NewConfigPath" -Level ERROR
    exit 1
}
Write-Log "Source file validated OK."

# ── 2. Ensure target directory exists ───────────────────────────────────────
if (-not (Test-Path $TargetDir)) {
    Write-Log "Target directory does not exist: $TargetDir" -Level ERROR
    exit 1
}
Write-Log "Target directory validated OK."

# ── 3. Backup existing config ────────────────────────────────────────────────
if (Test-Path $TargetFile) {
    Write-Log "Backing up existing config to: $BackupFile"
    try {
        Copy-Item -Path $TargetFile -Destination $BackupFile -Force -ErrorAction Stop
        Write-Log "Backup created successfully."
    } catch {
        Write-Log "Failed to create backup: $_" -Level ERROR
        exit 1
    }
} else {
    Write-Log "No existing winlog.yml found — skipping backup." -Level WARN
}

# ── 4. Copy new config ───────────────────────────────────────────────────────
Write-Log "Copying new winlog.yml..."
try {
    Copy-Item -Path $NewConfigPath -Destination $TargetFile -Force -ErrorAction Stop
    Write-Log "File replaced successfully."
} catch {
    Write-Log "Failed to copy new config: $_" -Level ERROR
    exit 1
}

# ── 5. Restart the service ───────────────────────────────────────────────────
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $svc) {
    Write-Log "Service '$ServiceName' not found." -Level ERROR
    exit 1
}

Write-Log "Restarting service: $ServiceName (current status: $($svc.Status))"
try {
    Restart-Service -Name $ServiceName -Force -ErrorAction Stop
    Start-Sleep -Seconds 3

    $svc.Refresh()
    if ($svc.Status -eq 'Running') {
        Write-Log "Service '$ServiceName' is running — deployment complete."
    } else {
        Write-Log "Service '$ServiceName' status after restart: $($svc.Status)" -Level WARN
    }
} catch {
    Write-Log "Failed to restart service: $_" -Level ERROR

    # ── Rollback on failure ──────────────────────────────────────────────────
    if (Test-Path $BackupFile) {
        Write-Log "Rolling back to backup config..." -Level WARN
        try {
            Copy-Item -Path $BackupFile -Destination $TargetFile -Force -ErrorAction Stop
            Restart-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Write-Log "Rollback complete. Investigate the new config file." -Level WARN
        } catch {
            Write-Log "Rollback also failed: $_" -Level ERROR
        }
    }
    exit 1
}

Write-Log "===== winlog.yml replacement finished ====="