# Preflight check for init-gas-project.bat / init-gas-project.ps1
# Checks:
# - git
# - node
# - clasp installed
# - clasp login completed
# - gh installed
# - gh auth login completed

$ErrorActionPreference = 'Stop'

function Write-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [bool]$Ok,
        [string]$Details = ''
    )

    if ($Ok) {
        Write-Host "[OK]  $Label" -ForegroundColor Green
    } else {
        Write-Host "[NG]  $Label" -ForegroundColor Red
    }

    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        Write-Host "      $Details" -ForegroundColor Gray
    }
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Test-ClaspLogin {
    $path = Join-Path $HOME '.clasprc.json'
    if (-not (Test-Path $path)) {
        return @{ Ok = $false; Details = "$path was not found. Run: clasp login" }
    }

    try {
        $json = Get-Content -Path $path -Raw | ConvertFrom-Json
        $token = $json.tokens.default
        if (-not $token -or [string]::IsNullOrWhiteSpace([string]$token.refresh_token)) {
            return @{ Ok = $false; Details = "$path does not contain refresh_token. Run: clasp login" }
        }

        return @{ Ok = $true; Details = "$path exists and token data looks valid." }
    } catch {
        return @{ Ok = $false; Details = "Failed to parse $path. Run: clasp login" }
    }
}

function Test-GhAuth {
    try {
        & gh auth status 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) {
            return @{ Ok = $true; Details = 'gh auth status succeeded.' }
        }

        return @{ Ok = $false; Details = 'Run: gh auth login' }
    } catch {
        return @{ Ok = $false; Details = 'Run: gh auth login' }
    }
}

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS preflight check' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

$allOk = $true

$nodeOk = Test-CommandExists -CommandName 'node'
Write-Status -Label 'node available' -Ok $nodeOk -Details ($(if ($nodeOk) { "$(node -v)" } else { 'node command not found.' }))
$allOk = $allOk -and $nodeOk

$gitOk = Test-CommandExists -CommandName 'git'
Write-Status -Label 'git available' -Ok $gitOk -Details ($(if ($gitOk) { "$(git --version)" } else { 'git command not found.' }))
$allOk = $allOk -and $gitOk

$claspOk = Test-CommandExists -CommandName 'clasp'
Write-Status -Label 'clasp available' -Ok $claspOk -Details ($(if ($claspOk) { "$(clasp --version)" } else { 'clasp command not found. Run installer script.' }))
$allOk = $allOk -and $claspOk

$claspLogin = Test-ClaspLogin
Write-Status -Label 'clasp login completed' -Ok $claspLogin.Ok -Details $claspLogin.Details
$allOk = $allOk -and $claspLogin.Ok

$ghOk = Test-CommandExists -CommandName 'gh'
Write-Status -Label 'gh available' -Ok $ghOk -Details ($(if ($ghOk) { "$(gh --version | Select-Object -First 1)" } else { 'gh command not found. Run installer script.' }))
$allOk = $allOk -and $ghOk

if ($ghOk) {
    $ghAuth = Test-GhAuth
    Write-Status -Label 'gh auth login completed' -Ok $ghAuth.Ok -Details $ghAuth.Details
    $allOk = $allOk -and $ghAuth.Ok
}

$batPath = Join-Path $PSScriptRoot 'init-gas-project.bat'
$ps1Path = Join-Path $PSScriptRoot 'init-gas-project.ps1'
$initScriptsOk = (Test-Path $batPath) -and (Test-Path $ps1Path)
Write-Status -Label 'init scripts exist' -Ok $initScriptsOk -Details 'Checked init-gas-project.bat and init-gas-project.ps1'
$allOk = $allOk -and $initScriptsOk

Write-Host ''
if ($allOk) {
    Write-Host 'All prerequisites are ready. You can run init-gas-project.bat.' -ForegroundColor Green
    exit 0
}

Write-Host 'Some prerequisites are missing. Fix [NG] items and rerun this check.' -ForegroundColor Red
Write-Host 'To install tools, run: installers\install-gas-prerequisites.bat' -ForegroundColor Yellow
exit 1
