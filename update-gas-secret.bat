@echo off
REM Windows wrapper for quick GAS secret update
REM Run this from the project folder after clasp login

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PS_SCRIPT=%~dp0update-gas-secret.ps1"

if not exist "!PS_SCRIPT!" (
    echo Error: update-gas-secret.ps1 not found in %~dp0
    pause
    exit /b 1
)

REM Pass all arguments to PowerShell script
set "ARGS="
if not "%~1"=="" (
    set "ARGS=-EnvironmentNames '%~1'"
)

powershell -NoExit -ExecutionPolicy Bypass -File "!PS_SCRIPT!" !ARGS!

endlocal
