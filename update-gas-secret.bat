@echo off
REM Windows wrapper for quick GAS secret update
REM Run this from the project folder after clasp login

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PS_SCRIPT=%~dp0update-gas-secret.ps1"
set "FALLBACK_PS_SCRIPT=%~dp0..\gas-Initializer\update-gas-secret.ps1"

if not exist "!PS_SCRIPT!" (
    if exist "!FALLBACK_PS_SCRIPT!" (
        set "PS_SCRIPT=!FALLBACK_PS_SCRIPT!"
        echo Info: local update-gas-secret.ps1 not found. Using fallback:
        echo       !PS_SCRIPT!
    ) else (
        echo Error: update-gas-secret.ps1 not found.
        echo Checked:
        echo   - %~dp0update-gas-secret.ps1
        echo   - %~dp0..\gas-Initializer\update-gas-secret.ps1
        pause
        exit /b 1
    )
)

REM Pass all arguments to PowerShell script
set "ARGS="
if not "%~1"=="" (
    set "ARGS=-EnvironmentNames '%~1'"
)

powershell -NoExit -ExecutionPolicy Bypass -File "!PS_SCRIPT!" !ARGS!

endlocal
