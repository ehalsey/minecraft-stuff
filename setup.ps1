# Minecraft utilities setup — installs the backup/restore/sync scripts on this computer,
# registers the 15-minute auto-backup task, and remembers a shared sync location so
# moving worlds between machines is one-click.
#
# Run it two ways:
#   * From a clone of this repo:   .\setup.ps1
#   * On a fresh PC (no clone), one line in PowerShell — downloads everything from GitHub:
#       iwr https://raw.githubusercontent.com/ehalsey/minecraft-stuff/main/setup.ps1 -OutFile "$env:TEMP\mc-setup.ps1"; & "$env:TEMP\mc-setup.ps1"
#
# Params (all optional; without them it asks interactively):
#   -SyncLocation <path>  shared folder to remember (USB, network share, OneDrive, ...)
#   -NoTask               don't register the scheduled backup task
#   -NoPrompt             non-interactive: install + task + given -SyncLocation, no questions
param(
    [string]$SyncLocation,
    [switch]$NoTask,
    [switch]$NoPrompt
)
$ErrorActionPreference = 'Stop'

$repo   = 'ehalsey/minecraft-stuff'
$branch = 'main'
$files  = @(
    'backups/backup-world.ps1',
    'backups/restore-world.ps1',
    'backups/sync-backups.ps1',
    'backups/Backup-Minecraft-World.bat',
    'backups/Restore-Minecraft-World.bat',
    'backups/Sync-Minecraft-Backups.bat'
)

$dest = Join-Path $env:APPDATA '.minecraft\backups'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host ''
Write-Host "Installing Minecraft utilities to: $dest" -ForegroundColor Cyan

# Prefer files from a local checkout (this script sits at the repo root); otherwise
# download each from GitHub raw so setup works on a machine that has no clone.
foreach ($rel in $files) {
    $name     = Split-Path $rel -Leaf
    $target   = Join-Path $dest $name
    $localSrc = Join-Path $PSScriptRoot $rel
    if (Test-Path $localSrc) {
        Copy-Item $localSrc $target -Force
        Write-Host "  installed (local)      $name"
    }
    else {
        $url = "https://raw.githubusercontent.com/$repo/$branch/$rel"
        Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
        Write-Host "  installed (downloaded) $name"
    }
}

# --- 15-minute auto-backup scheduled task --------------------------------------
$taskName = 'Minecraft World Backup'
$registerTask = -not $NoTask
if ($registerTask -and -not $NoPrompt) {
    $ans = Read-Host "Register the 15-minute auto-backup task '$taskName'? [Y/n]"
    if ($ans -match '^(n|no)$') { $registerTask = $false }
}
if ($registerTask) {
    $ps1 = Join-Path $dest 'backup-world.ps1'
    try {
        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ps1`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Minutes 15) `
            -RepetitionDuration (New-TimeSpan -Days 3650)
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Settings $settings -Force `
            -Description 'Creates timestamped Minecraft world restore points every 15 minutes.' | Out-Null
        Write-Host "  scheduled task '$taskName' registered (every 15 min)." -ForegroundColor Green
    }
    catch {
        # Fallback for hosts where the ScheduledTasks module misbehaves.
        $tr = "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ps1`""
        schtasks.exe /Create /TN $taskName /TR $tr /SC MINUTE /MO 15 /IT /F | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  scheduled task '$taskName' registered via schtasks." -ForegroundColor Green
        }
        else {
            Write-Host "  could not register the scheduled task: $_" -ForegroundColor Yellow
            Write-Host "  (you can still back up any time with Backup-Minecraft-World.bat)"
        }
    }
}

# --- remember a shared sync location -------------------------------------------
$syncFile = Join-Path $dest 'sync-location.txt'
if (-not $SyncLocation -and -not $NoPrompt) {
    Write-Host ''
    Write-Host 'Shared folder both computers can see, for moving worlds between them.'
    Write-Host 'A USB drive, a network share, or a cloud-synced folder. Examples:'
    Write-Host '  E:\    \\NAS\minecraft    (or your OneDrive folder)'
    $existing = ''
    if (Test-Path $syncFile) { $existing = (Get-Content $syncFile -Raw).Trim() }
    if ($existing) { Write-Host "Currently remembered: $existing" -ForegroundColor DarkGray }
    $SyncLocation = Read-Host 'Path to remember (or Enter to skip)'
}
if ($SyncLocation) {
    Set-Content -Path $syncFile -Value $SyncLocation
    Write-Host "  remembered sync location: $SyncLocation" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host 'Scripts installed. From now on you can:'
Write-Host '  - back up now:      Backup-Minecraft-World.bat'
Write-Host '  - restore a world:  Restore-Minecraft-World.bat'
Write-Host '  - sync to/from PCs: Sync-Minecraft-Backups.bat'
Write-Host "(all in $dest)"
if (-not $NoPrompt) { Read-Host 'Press Enter to close' }
