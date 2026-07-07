@echo off
REM Windows Initial GAS Project Setup Wrapper
REM This batch file launches the PowerShell script with appropriate settings

setlocal enabledelayedexpansion
cd /d "%~dp0"

REM Get the PowerShell script path
set "PS_SCRIPT=%~dp0init-gas-project.ps1"

REM Check if PowerShell script exists
if not exist "!PS_SCRIPT!" (
    echo Error: init-gas-project.ps1 not found in %~dp0
    pause
    exit /b 1
)

REM Launch PowerShell with the script
REM -NoExit keeps the window open so user can see any errors
REM -ExecutionPolicy Bypass allows running the script without admin
powershell -NoExit -ExecutionPolicy Bypass -File "!PS_SCRIPT!"

endlocal
