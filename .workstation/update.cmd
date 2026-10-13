@echo off
setlocal
REM Double-click entry: preview the upgrades, ask before applying any, then verify. Implementation remains in update.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
set "ORVION_EXIT=%ERRORLEVEL%"
pause
exit /b %ORVION_EXIT%
