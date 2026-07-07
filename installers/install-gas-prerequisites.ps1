# Installs prerequisites for GAS initial setup on Windows.
# Supports:
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
        throw 'このスクリプトは Windows 環境向けです。'
    }
}

function Install-GitHubCli {
    Write-Section 'GitHub CLI のインストール'

    if (Test-CommandExists -Name 'gh') {
        Write-Host 'gh は既にインストールされています。' -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists -Name 'winget')) {
        throw 'winget が見つかりません。GitHub CLI は手動でインストールしてください: https://cli.github.com/'
    }

    Write-Host 'winget で GitHub CLI をインストールします...' -ForegroundColor Cyan
    & winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub CLI のインストールに失敗しました。'
    }

    if (-not (Test-CommandExists -Name 'gh')) {
        throw 'GitHub CLI のインストール後も gh が見つかりません。'
    }

    Write-Host '✓ GitHub CLI のインストールが完了しました。' -ForegroundColor Green
}

function Install-Clasp {
    Write-Section 'clasp のインストール'

    if (Test-CommandExists -Name 'clasp') {
        Write-Host 'clasp は既にインストールされています。' -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists -Name 'npm')) {
        throw 'npm が見つかりません。Node.js をインストールしてから再実行してください: https://nodejs.org/'
    }

    Write-Host 'npm で clasp をグローバルインストールします...' -ForegroundColor Cyan
    & npm install -g @google/clasp
    if ($LASTEXITCODE -ne 0) {
        throw 'clasp のインストールに失敗しました。'
    }

    if (-not (Test-CommandExists -Name 'clasp')) {
        throw 'clasp のインストール後も clasp が見つかりません。'
    }

    Write-Host '✓ clasp のインストールが完了しました。' -ForegroundColor Green
}

Assert-Windows

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS 初回構築 用インストール' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

$selectedTarget = $Target
if ($selectedTarget -eq 'all') {
    $missing = @()
    if (-not (Test-CommandExists -Name 'clasp')) { $missing += 'clasp' }
    if (-not (Test-CommandExists -Name 'gh')) { $missing += 'gh' }

    if ($missing.Count -eq 0) {
        Write-Host '必要なツールはすべて既にインストールされています。' -ForegroundColor Green
        exit 0
    }

    Write-Host ('不足しているツール: ' + ($missing -join ', ')) -ForegroundColor White
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
Write-Host '✓ インストールが完了しました！' -ForegroundColor Green
Write-Host '================================' -ForegroundColor Green
Write-Host ''
Write-Host 'このウィンドウを閉じるには、任意のキーを押してください...' -ForegroundColor Gray
[void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
