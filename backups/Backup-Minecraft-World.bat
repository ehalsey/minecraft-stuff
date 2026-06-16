@echo off
title Minecraft World Backup
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPDATA%\.minecraft\backups\backup-world.ps1"
echo.
pause
