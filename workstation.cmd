@echo off
setlocal
REM One-click workstation entry. Implementation remains in .workstation\prepare.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.workstation\prepare.ps1"
set "ORVION_EXIT=%ERRORLEVEL%"
if not "%ORVION_EXIT%"=="0" pause
exit /b %ORVION_EXIT%
