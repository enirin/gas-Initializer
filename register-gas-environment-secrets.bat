@echo off
REM Windows wrapper for registering GitHub Environments secrets

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PS_SCRIPT=%~dp0register-gas-environment-secrets.ps1"

if not exist "!PS_SCRIPT!" (
    echo Error: register-gas-environment-secrets.ps1 not found in %~dp0
    pause
    exit /b 1
)

powershell -NoExit -ExecutionPolicy Bypass -File "!PS_SCRIPT!"

endlocal
