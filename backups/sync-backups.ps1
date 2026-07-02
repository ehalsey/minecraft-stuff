# Minecraft backup sync — carry your restore points between computers so you can
# pick up where you left off on another PC.
#
# It copies the .zip restore points (created by backup-world.ps1) to/from a SHARED
# LOCATION that both computers can see: a USB drive, a network share, or a cloud-
# synced folder (OneDrive/Dropbox). Nothing about the game is touched here — this
# only moves the backup archives. To actually load a synced world, run
# restore-world.ps1 afterwards (Pull can launch it for you).
#
#   Push : this computer's backups  ->  shared location   (do this where you played)
#   Pull : shared location -> this computer's backups      (do this on the other PC)
#
# By default only the NEWEST few restore points per world are moved — that's all you need
# to continue on another PC, and it keeps transfers small. Use -Count N to change how many,
# or -All to sync the full history. Copies are ADDITIVE — nothing is ever deleted on either
# side, so the shared store still accumulates a sparse offsite history over time. After
# copying, each world's counter.txt is reconciled to the highest ID seen, so the stable
# #IDs stay monotonic across machines.
#
# Examples:
#   .\sync-backups.ps1                              # interactive (pick mode + location)
#   .\sync-backups.ps1 -Mode Push -Location E:\     # newest 3 per world
#   .\sync-backups.ps1 -Mode Push -Location E:\ -Count 5
#   .\sync-backups.ps1 -Mode Pull -Location \\NAS\minecraft -All -Restore
param(
    [ValidateSet('Push', 'Pull')][string]$Mode,
    [string]$Location,
    [int]$Count = 3,
    [switch]$All,
    [switch]$Restore
)
$ErrorActionPreference = 'Stop'

$backupRoot = Join-Path $env:APPDATA '.minecraft\backups'
$worlds     = 'main', 'ai'
$storeName  = 'minecraft-world-backups'   # subfolder created at the shared location

# --- pick mode (Push/Pull) if not passed ---------------------------------------
if (-not $Mode) {
    Write-Host ''
    Write-Host 'Sync Minecraft backups between computers.' -ForegroundColor Cyan
    Write-Host '  1: Push  - copy THIS computer''s backups TO the shared location'
    Write-Host '  2: Pull  - copy backups FROM the shared location to THIS computer'
    $m = Read-Host 'Enter number (or Enter to cancel)'
    switch ($m) {
        '1'     { $Mode = 'Push' }
        '2'     { $Mode = 'Pull' }
        default { Write-Host 'Cancelled.'; exit }
    }
}

# --- pick shared location if not passed ----------------------------------------
# Default to the location setup.ps1 remembered (sync-location.txt), else OneDrive.
if (-not $Location) {
    $suggest = $null
    $saved   = Join-Path $PSScriptRoot 'sync-location.txt'
    if (Test-Path $saved) { $suggest = (Get-Content $saved -Raw).Trim() }
    if (-not $suggest) { $suggest = $env:OneDrive }
    if (-not $suggest) { $suggest = $env:OneDriveConsumer }
    Write-Host ''
    Write-Host 'Shared location both computers can see (USB drive, network share, or'
    Write-Host 'a cloud-synced folder like OneDrive). Examples: E:\   \\NAS\minecraft'
    if ($suggest) { Write-Host "Press Enter to use: $suggest" -ForegroundColor DarkGray }
    $Location = Read-Host 'Path'
    if (-not $Location) {
        if ($suggest) { $Location = $suggest } else { Write-Host 'No location given. Cancelled.'; exit }
    }
}

$store = Join-Path $Location $storeName
if ($Mode -eq 'Pull' -and -not (Test-Path $store)) {
    Write-Host "Nothing to pull: no '$storeName' folder found at $Location" -ForegroundColor Red
    Write-Host '(Did you run a Push from the other computer first?)'
    Read-Host 'Press Enter'; exit
}

# Reconcile a world folder's counter.txt to the highest ID present, so the stable
# #IDs never go backwards after a merge.
function Update-Counter($dir) {
    if (-not (Test-Path $dir)) { return }
    $counterFile = Join-Path $dir 'counter.txt'
    $maxFile = (Get-ChildItem -Path $dir -Filter 'world_*.zip' -ErrorAction SilentlyContinue |
        ForEach-Object { if ($_.Name -match '^world_(\d+)_') { [int]$Matches[1] } } |
        Measure-Object -Maximum).Maximum
    $cur = 0
    if (Test-Path $counterFile) {
        [int]::TryParse((Get-Content $counterFile -Raw).Trim(), [ref]$cur) | Out-Null
    }
    Set-Content -Path $counterFile -Value ([Math]::Max([int]$maxFile, $cur))
}

$scope = if ($All) { 'all restore points' } else { "newest $Count per world" }
Write-Host ''
Write-Host "$Mode  ($scope -> shared store: $store)" -ForegroundColor Cyan

$copied = $false
foreach ($w in $worlds) {
    $local = Join-Path $backupRoot $w
    $shared = Join-Path $store $w
    if ($Mode -eq 'Push') { $src = $local;  $dst = $shared }
    else                  { $src = $shared; $dst = $local  }

    $available = Get-ChildItem -Path $src -Filter 'world_*.zip' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $available) {
        Write-Host "[$w] no restore points to copy from $src - skipping."
        continue
    }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null

    # Pick the newest N (or everything with -All).
    $pick = if ($All) { $available } else { $available | Select-Object -First $Count }

    # Additive copy: only bring over ones the destination doesn't already have; never delete.
    # counter.txt is not copied — it's reconciled below so a stale counter can't roll IDs back.
    $new = 0
    foreach ($f in $pick) {
        $target = Join-Path $dst $f.Name
        if (-not (Test-Path $target)) { Copy-Item -Path $f.FullName -Destination $target -Force; $new++ }
    }
    Update-Counter $dst
    $copied = $true
    $total = (Get-ChildItem -Path $dst -Filter 'world_*.zip').Count
    Write-Host "[$w] $Mode complete - $new new copied, $total total at destination." -ForegroundColor Green
}

if (-not $copied) {
    Write-Host ''
    Write-Host 'Nothing was copied.' -ForegroundColor Yellow
    Read-Host 'Press Enter'; exit
}

Write-Host ''
if ($Mode -eq 'Push') {
    Write-Host 'Push done. On the other computer, run this script with Pull to bring them over.' -ForegroundColor Green
    Read-Host 'Press Enter to close'
}
else {
    Write-Host 'Pull done. Your restore points are now on this computer.' -ForegroundColor Green
    $doRestore = $Restore
    if (-not $doRestore) {
        $r = Read-Host 'Restore one now? (close Minecraft first) [y/N]'
        $doRestore = ($r -match '^(y|yes)$')
    }
    if ($doRestore) {
        & (Join-Path $PSScriptRoot 'restore-world.ps1')
    }
    else {
        Write-Host 'Run restore-world.ps1 when you''re ready to load a world.'
        Read-Host 'Press Enter to close'
    }
}
