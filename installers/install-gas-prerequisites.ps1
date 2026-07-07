# Installs prerequisites for GAS initial setup on Windows.
# Targets:
# - clasp (@google/clasp)
# - GitHub CLI (gh)

param(
    [ValidateSet('all', 'clasp', 'gh')]
    [string]$Target = 'all'
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ''
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-Windows {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw 'This script supports Windows only.'
    }
}

function Install-GitHubCli {
    Write-Section 'Install GitHub CLI'

    if (Test-CommandExists -Name 'gh') {
        Write-Host 'gh is already installed.' -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists -Name 'winget')) {
        throw 'winget is not available. Install GitHub CLI manually: https://cli.github.com/'
    }

    Write-Host 'Installing GitHub CLI with winget...' -ForegroundColor Cyan
    & winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to install GitHub CLI.'
    }

    if (-not (Test-CommandExists -Name 'gh')) {
        throw 'GitHub CLI was installed but gh is still not found in PATH. Restart terminal and retry.'
    }

    Write-Host 'GitHub CLI installation completed.' -ForegroundColor Green
}

function Install-Clasp {
    Write-Section 'Install clasp'

    if (Test-CommandExists -Name 'clasp') {
        Write-Host 'clasp is already installed.' -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists -Name 'npm')) {
        throw 'npm is not available. Install Node.js first: https://nodejs.org/'
    }

    Write-Host 'Installing clasp with npm...' -ForegroundColor Cyan
    & npm install -g @google/clasp
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to install clasp.'
    }

    if (-not (Test-CommandExists -Name 'clasp')) {
        throw 'clasp was installed but not found in PATH. Restart terminal and retry.'
    }

    Write-Host 'clasp installation completed.' -ForegroundColor Green
}

Assert-Windows

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS prerequisite installer' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

$selectedTarget = $Target
if ($selectedTarget -eq 'all') {
    $missing = @()
    if (-not (Test-CommandExists -Name 'clasp')) { $missing += 'clasp' }
    if (-not (Test-CommandExists -Name 'gh')) { $missing += 'gh' }

    if ($missing.Count -eq 0) {
        Write-Host 'All required tools are already installed.' -ForegroundColor Green
        exit 0
    }

    Write-Host ('Missing tools: ' + ($missing -join ', ')) -ForegroundColor White
    Write-Host ''

    if ($missing -contains 'gh') {
        Install-GitHubCli
    }

    if ($missing -contains 'clasp') {
        Install-Clasp
    }
} elseif ($selectedTarget -eq 'gh') {
    Install-GitHubCli
} elseif ($selectedTarget -eq 'clasp') {
    Install-Clasp
}

Write-Host ''
Write-Host '================================' -ForegroundColor Green
Write-Host 'Installation completed.' -ForegroundColor Green
Write-Host '================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Press any key to close this window...' -ForegroundColor Gray
[void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
