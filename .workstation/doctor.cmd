@echo off
setlocal
REM Double-click entry: verify only, never installs or repairs. Implementation remains in doctor.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0doctor.ps1"
set "ORVION_EXIT=%ERRORLEVEL%"
pause
exit /b %ORVION_EXIT%
