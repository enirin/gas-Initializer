# Quick GAS environment secret update
# Run this script from the project folder after `clasp login`
# Automatically detects ProjectPath, Repository, and ScriptId from current folder

param(
    [string[]]$EnvironmentNames
)

$ErrorActionPreference = 'Stop'

# Verify current folder has .clasp.json
$currentPath = Get-Location
$claspJsonPath = Join-Path $currentPath '.clasp.json'
if (-not (Test-Path $claspJsonPath)) {
    Write-Host 'Error: .clasp.json not found in current directory.' -ForegroundColor Red
    Write-Host "Current: $currentPath" -ForegroundColor Red
    Write-Host 'Run this script from the project folder.' -ForegroundColor Yellow
    pause
    exit 1
}

# Extract ScriptId from .clasp.json
try {
    $claspJson = Get-Content $claspJsonPath -Raw | ConvertFrom-Json
    $scriptId = $claspJson.scriptId
    if ([string]::IsNullOrWhiteSpace($scriptId)) {
        throw 'scriptId not found in .clasp.json'
    }
} catch {
    Write-Host "Error: Failed to read ScriptId from .clasp.json: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

# Extract Repository from .git/config
$gitConfigPath = Join-Path $currentPath '.git' 'config'
if (-not (Test-Path $gitConfigPath)) {
    Write-Host 'Error: .git/config not found. Initialize git repository first.' -ForegroundColor Red
    pause
    exit 1
}

try {
    $gitConfig = Get-Content $gitConfigPath -Raw
    if ($gitConfig -match '\[remote "origin"\]\s+url\s*=\s*(.+)') {
        $remoteUrl = $Matches[1].Trim()
        if ($remoteUrl -match '(?:https?://|git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(?:\.git)?$') {
            $repository = "$($Matches.owner)/$($Matches.repo)"
        } else {
            throw "Could not parse GitHub repository from remote.origin.url: $remoteUrl"
        }
    } else {
        throw 'remote.origin.url not found in .git/config'
    }
} catch {
    Write-Host "Error: Failed to detect repository: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

# Default to production if not provided
if ($EnvironmentNames.Count -eq 0 -or [string]::IsNullOrWhiteSpace($EnvironmentNames[0])) {
    $EnvironmentNames = @('production')
}

# Summary display
Write-Host ''
Write-Host '======================================' -ForegroundColor Cyan
Write-Host 'GAS Secret Quick Update' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan
Write-Host "Project Path:    $currentPath" -ForegroundColor White
Write-Host "Repository:      $repository" -ForegroundColor White
Write-Host "Script ID:       $scriptId" -ForegroundColor White
Write-Host "Environments:    $($EnvironmentNames -join ', ')" -ForegroundColor White
Write-Host '======================================' -ForegroundColor Cyan
Write-Host ''

$confirm = Read-Host 'Proceed? (y/n, default: y)'
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host 'Cancelled.' -ForegroundColor Yellow
    exit 0
}

# Call the main script with auto-detected values
$registerScript = Join-Path (Split-Path $PSCommandPath) 'register-gas-environment-secrets.ps1'
if (-not (Test-Path $registerScript)) {
    Write-Host "Error: register-gas-environment-secrets.ps1 not found at: $registerScript" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ''
& $registerScript -ProjectPath $currentPath -Repository $repository -EnvironmentNames $EnvironmentNames -ScriptId $scriptId
