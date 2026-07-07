# Preflight check for init-gas-project.bat / init-gas-project.ps1
# Checks whether the basic prerequisites are ready:
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
        return @{ Ok = $false; Details = "${path} が見つかりません。`clasp login` を実行してください。" }
    }

    try {
        $json = Get-Content -Path $path -Raw | ConvertFrom-Json
        $token = $json.tokens.default
        if (-not $token -or [string]::IsNullOrWhiteSpace([string]$token.refresh_token)) {
            return @{ Ok = $false; Details = "${path} に refresh_token がありません。`clasp login` を再実行してください。" }
        }
        return @{ Ok = $true; Details = "${path} が存在し、認証情報も見つかりました。" }
    } catch {
        return @{ Ok = $false; Details = "${path} の読み取りに失敗しました。`clasp login` を再実行してください。" }
    }
}

function Test-GhAuth {
    try {
        & gh auth status 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) {
            return @{ Ok = $true; Details = "gh auth status が成功しました。" }
        }
        return @{ Ok = $false; Details = "`gh auth login` を実行してください。" }
    } catch {
        return @{ Ok = $false; Details = "`gh auth login` を実行してください。" }
    }
}

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS 初回構築 前提条件チェック' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

$allOk = $true

$nodeOk = Test-CommandExists -CommandName 'node'
Write-Status -Label 'node が利用可能' -Ok $nodeOk -Details ($(if ($nodeOk) { "$(node -v)" } else { 'node が見つかりません。' }))
$allOk = $allOk -and $nodeOk

$gitOk = Test-CommandExists -CommandName 'git'
Write-Status -Label 'git が利用可能' -Ok $gitOk -Details ($(if ($gitOk) { "$(git --version)" } else { 'git が見つかりません。' }))
$allOk = $allOk -and $gitOk

$claspOk = Test-CommandExists -CommandName 'clasp'
Write-Status -Label 'clasp が利用可能' -Ok $claspOk -Details ($(if ($claspOk) { "$(clasp --version)" } else { 'clasp が見つかりません。npm install -g @google/clasp を実行してください。' }))
$allOk = $allOk -and $claspOk

$claspLogin = Test-ClaspLogin
Write-Status -Label 'clasp login 済み' -Ok $claspLogin.Ok -Details $claspLogin.Details
$allOk = $allOk -and $claspLogin.Ok

$ghOk = Test-CommandExists -CommandName 'gh'
Write-Status -Label 'gh が利用可能' -Ok $ghOk -Details ($(if ($ghOk) { "$(gh --version | Select-Object -First 1)" } else { 'gh が見つかりません。GitHub CLI をインストールしてください。' }))
$allOk = $allOk -and $ghOk

if ($ghOk) {
    $ghAuth = Test-GhAuth
    Write-Status -Label 'gh auth login 済み' -Ok $ghAuth.Ok -Details $ghAuth.Details
    $allOk = $allOk -and $ghAuth.Ok
}

$batPath = Join-Path $PSScriptRoot 'init-gas-project.bat'
$ps1Path = Join-Path $PSScriptRoot 'init-gas-project.ps1'
Write-Status -Label '初期化スクリプトが存在' -Ok ((Test-Path $batPath) -and (Test-Path $ps1Path)) -Details "init-gas-project.bat / init-gas-project.ps1 を確認しました。"
$allOk = $allOk -and ((Test-Path $batPath) -and (Test-Path $ps1Path))

Write-Host ''
if ($allOk) {
    Write-Host '前提条件は揃っています。init-gas-project.bat を実行できます。' -ForegroundColor Green
    exit 0
}

Write-Host '前提条件が不足しています。上記の [NG] を解消してから再実行してください。' -ForegroundColor Red
Write-Host '不足ツールのインストールには installers\install-gas-prerequisites.bat を実行できます。' -ForegroundColor Yellow
exit 1
