@echo off
setlocal enabledelayedexpansion

:: Sets
set "oh_theme=night-owl"

set "scriptPath=%~dp0"

:: Admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo The script is not running as administrator! Re-run it!
    powershell -command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser"
powershell -file "%scriptPath%main.ps1" -nano -cmd -ps7 -ps_profile -terminal -oh_theme %oh_theme%

pause
exit /b
