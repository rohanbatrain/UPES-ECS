@echo off
REM UPES-ECS - one double-click to bind the PBX to the router you're on now.
REM For the van operator: after moving to a new router / OTG hotspot, run this.
REM Works with NO internet. Prints the IP to give the ERT phones, then waits.
title UPES-ECS  -  Rebind to this network
echo.
echo   Binding the emergency PBX to the current network...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-UpesLanIp.ps1"
echo.
echo   Done. Press any key to close.
pause >nul
