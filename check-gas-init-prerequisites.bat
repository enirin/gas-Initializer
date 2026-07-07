@echo off
REM Preflight check wrapper for GAS initial setup

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PS_SCRIPT=%~dp0check-gas-init-prerequisites.ps1"

if not exist "!PS_SCRIPT!" (
    echo Error: check-gas-init-prerequisites.ps1 not found in %~dp0
    pause
    exit /b 1
)

powershell -NoExit -ExecutionPolicy Bypass -File "!PS_SCRIPT!"

endlocal
