# Run this on a NEW / OTHER computer to get your Minecraft worlds there.
# It (1) installs the backup/restore/sync tools + the 15-minute auto-backup task,
# then (2) pulls your restore points from your OneDrive and offers to restore.
#
# Requires: this PC signed into the same OneDrive, and OneDrive finished syncing the
# 'minecraft-world-backups' folder down. Close Minecraft before restoring.
$ErrorActionPreference = 'Stop'

Write-Host 'Installing Minecraft backup tools...' -ForegroundColor Cyan
$setup = Join-Path $env:TEMP 'mc-setup.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/ehalsey/minecraft-stuff/main/setup.ps1' `
    -OutFile $setup -UseBasicParsing
& $setup -SyncLocation $env:OneDrive -NoPrompt

Write-Host ''
Write-Host 'Pulling your worlds from OneDrive...' -ForegroundColor Cyan
& (Join-Path $env:APPDATA '.minecraft\backups\sync-backups.ps1') -Mode Pull -Location $env:OneDrive
