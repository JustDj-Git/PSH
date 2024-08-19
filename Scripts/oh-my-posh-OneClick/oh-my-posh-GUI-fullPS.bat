@echo off
setlocal enabledelayedexpansion

:: Sets
set "scriptPath=%~dp0"

powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser"
powershell -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0menu.ps1""' -Verb RunAs}"

exit /b
