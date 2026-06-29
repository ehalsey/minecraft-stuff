# Minecraft world restore — puts a chosen restore point back, for either install.
# CLOSE Minecraft before running this.
$ErrorActionPreference = 'Stop'

$backupRoot = Join-Path $env:APPDATA '.minecraft\backups'
$sets = @(
    @{ Name = 'main (26.1.2)'; Saves = Join-Path $env:APPDATA '.minecraft\saves';    Dest = Join-Path $backupRoot 'main' },
    @{ Name = 'ai (1.21.1)';   Saves = Join-Path $env:APPDATA '.minecraft-ai\saves'; Dest = Join-Path $backupRoot 'ai' }
)

Write-Host ''
Write-Host 'Which world do you want to restore?' -ForegroundColor Cyan
for ($i = 0; $i -lt $sets.Count; $i++) { '{0}: {1}' -f ($i + 1), $sets[$i].Name }
$w = Read-Host 'Enter number (or Enter to cancel)'
if (-not $w) { Write-Host 'Cancelled.'; exit }
$wi = [int]$w - 1
if ($wi -lt 0 -or $wi -ge $sets.Count) { Write-Host 'Invalid choice.'; Read-Host 'Press Enter'; exit }
$set = $sets[$wi]
$src = $set.Saves

$backups = Get-ChildItem -Path $set.Dest -Filter 'world_*.zip' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
if (-not $backups) { Write-Host "No restore points found for $($set.Name)."; Read-Host 'Press Enter'; exit }

Write-Host ''
Write-Host "Restore points for $($set.Name) (newest first):" -ForegroundColor Cyan
for ($i = 0; $i -lt $backups.Count; $i++) {
    $b = $backups[$i]
    $id = if ($b.Name -match '^world_(\d+)_') { '#{0}' -f [int]$Matches[1] } else { '—' }
    '{0,3}  {1,-7}  {2}   ({3})' -f ($i + 1), $id, $b.Name, $b.LastWriteTime
}
Write-Host ''
Write-Host 'Type the #ID (preferred, stable) or the row number on the left.' -ForegroundColor DarkGray
$choice = Read-Host 'Enter restore point (or Enter to cancel)'
if (-not $choice) { Write-Host 'Cancelled.'; exit }
$choice = $choice.Trim().TrimStart('#').Trim()

# Prefer a stable-ID match; fall back to the row number for legacy points without an ID.
$pick = $null
$num  = 0
if ([int]::TryParse($choice, [ref]$num)) {
    $pick = $backups | Where-Object { $_.Name -match '^world_(\d+)_' -and [int]$Matches[1] -eq $num } |
        Select-Object -First 1
    if (-not $pick -and $num -ge 1 -and $num -le $backups.Count) { $pick = $backups[$num - 1] }
}
if (-not $pick) { Write-Host 'Invalid choice.'; Read-Host 'Press Enter'; exit }

Write-Host ''
Write-Host "WARNING: this REPLACES the current $($set.Name) worlds with:" -ForegroundColor Yellow
Write-Host "  $($pick.Name)" -ForegroundColor Yellow
Write-Host 'Make sure Minecraft is CLOSED first.' -ForegroundColor Yellow
$confirm = Read-Host 'Type YES (capitals) to proceed'
if ($confirm -ne 'YES') { Write-Host 'Cancelled.'; exit }

New-Item -ItemType Directory -Force -Path $src | Out-Null

# Safety net: snapshot the current worlds before overwriting.
$stamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$safety = Join-Path $set.Dest "before-restore_$stamp.zip"
if (Get-ChildItem -Path $src -Force -ErrorAction SilentlyContinue) {
    try {
        Compress-Archive -Path (Join-Path $src '*') -DestinationPath $safety -CompressionLevel Optimal
        Write-Host "Saved current worlds to: $safety"
    } catch {
        Write-Host "Could not snapshot current worlds (is Minecraft still open?): $_" -ForegroundColor Red
        Read-Host 'Press Enter'; exit
    }
}

# Replace current worlds with the chosen restore point.
Get-ChildItem -Path $src -Force | Remove-Item -Recurse -Force
Expand-Archive -Path $pick.FullName -DestinationPath $src -Force

Write-Host ''
Write-Host "Restore complete for $($set.Name). Launch that profile - your world is back at that point." -ForegroundColor Green
Read-Host 'Press Enter to close'
