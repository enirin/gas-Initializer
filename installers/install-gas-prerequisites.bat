@echo off
REM Windows wrapper for GAS prerequisite installation

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PS_SCRIPT=%~dp0install-gas-prerequisites.ps1"

if not exist "!PS_SCRIPT!" (
    echo Error: install-gas-prerequisites.ps1 not found in %~dp0
    pause
    exit /b 1
)

powershell -NoExit -ExecutionPolicy Bypass -File "!PS_SCRIPT!"

endlocal
