@echo off
title Minecraft World Restore
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPDATA%\.minecraft\backups\restore-world.ps1"
