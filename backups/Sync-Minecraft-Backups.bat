@echo off
title Minecraft Backup Sync
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPDATA%\.minecraft\backups\sync-backups.ps1"
