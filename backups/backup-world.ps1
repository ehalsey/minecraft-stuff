# Minecraft world backup — creates timestamped .zip "restore points" for BOTH installs:
#   main = your 26.1.2 worlds (.minecraft\saves)
#   ai   = your 1.21.1 AI-Player worlds (.minecraft-ai\saves)
# Safe to run while playing: skips the locked session.lock and only backs up when something changed.
#
# Idle behavior: the task fires every 15 min, but it only does real work when Minecraft is
# RUNNING (an active session) OR a world changed since its last backup. The "changed" case is
# what captures the final save written when you quit, so your last session is never lost. When
# Minecraft is closed and nothing has changed, this exits immediately and creates nothing.
$ErrorActionPreference = 'Stop'

$backupRoot = Join-Path $env:APPDATA '.minecraft\backups'
$keep = 40   # restore points to keep per world before pruning the oldest

# Is Minecraft actually running right now? (its bundled Java runtime, or any java pointed at .minecraft)
$mcRunning = [bool](Get-Process javaw, java -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -match 'minecraft|java-runtime' })

$sources = @(
    @{ Name = 'main (26.1.2)'; Saves = Join-Path $env:APPDATA '.minecraft\saves';    Dest = Join-Path $backupRoot 'main' },
    @{ Name = 'ai (1.21.1)';   Saves = Join-Path $env:APPDATA '.minecraft-ai\saves'; Dest = Join-Path $backupRoot 'ai' }
)

foreach ($s in $sources) {
    if (-not (Test-Path $s.Saves) -or
        -not (Get-ChildItem -Path $s.Saves -Directory -ErrorAction SilentlyContinue)) {
        Write-Host "[$($s.Name)] no worlds yet - skipping."
        continue
    }
    New-Item -ItemType Directory -Force -Path $s.Dest | Out-Null

    # Skip if nothing changed since the most recent backup.
    $latestChange = (Get-ChildItem -Path $s.Saves -Recurse -File |
        Where-Object { $_.Name -ne 'session.lock' } |
        Measure-Object -Property LastWriteTime -Maximum).Maximum
    $lastBackup = Get-ChildItem -Path $s.Dest -Filter 'world_*.zip' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($lastBackup -and $latestChange -and $lastBackup.LastWriteTime -ge $latestChange) {
        $state = if ($mcRunning) { 'playing, but no new changes' } else { 'Minecraft closed and idle' }
        Write-Host "[$($s.Name)] $state since $($lastBackup.Name) - skipping."
        continue
    }

    # Copy to staging first (robocopy tolerates files the game has open), then zip.
    $staging = Join-Path $env:TEMP ('mc_backup_stage_' + ($s.Name -replace '[^a-zA-Z0-9]', ''))
    Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
    robocopy $s.Saves $staging /E /XF session.lock /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null

    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $zip   = Join-Path $s.Dest "world_$stamp.zip"
    Write-Host "[$($s.Name)] creating restore point: $zip"
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip -CompressionLevel Optimal
    Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue

    Get-ChildItem -Path $s.Dest -Filter 'world_*.zip' | Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $keep | Remove-Item -Force -ErrorAction SilentlyContinue
    $count = (Get-ChildItem -Path $s.Dest -Filter 'world_*.zip').Count
    Write-Host "[$($s.Name)] done. Restore points kept: $count"
}
