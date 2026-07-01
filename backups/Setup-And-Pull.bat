@echo off
title Minecraft - set up this PC and pull worlds from OneDrive
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull-setup.ps1"
echo.
pause
