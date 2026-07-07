# Windows script for registering GitHub Environments secrets for GAS / clasp
# - CLASP_CREDENTIALS_JSON
# - CLASP_SCRIPT_ID
# - CLASP_DEPLOYMENT_ID (optional)

param(
    [string[]]$EnvironmentNames,
    [string]$Repository,
    [string]$RepositoryUrl,
    [string]$ScriptId,
    [string]$DeploymentId
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Yellow
    Write-Host ''
}

function Resolve-GitHubRepositoryName {
    param(
        [string]$RepositoryInput,
        [string]$RepositoryUrlInput
    )

    if (-not [string]::IsNullOrWhiteSpace($RepositoryInput)) {
        return $RepositoryInput.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($RepositoryUrlInput)) {
        $normalized = $RepositoryUrlInput.Trim()
        if ($normalized -match '(?:https?://|ssh://)?(?:git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
            return "$($Matches.owner)/$($Matches.repo)"
        }
    }

    try {
        $remoteUrl = (& git remote get-url origin 2>$null).Trim()
        if (-not [string]::IsNullOrWhiteSpace($remoteUrl) -and $remoteUrl -match '(?:https?://|ssh://)?(?:git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
            return "$($Matches.owner)/$($Matches.repo)"
        }
    } catch {
        # fall through to error below
    }

    throw 'GitHub リポジトリ名を特定できませんでした。-Repository か -RepositoryUrl を指定してください。'
}

function Get-EnvironmentNames {
    param(
        [string[]]$InputNames
    )

    $resolved = @()
    foreach ($name in $InputNames) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $resolved += ($name -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    if ($resolved.Count -eq 0) {
        $prompt = Read-Host '対象 environment をカンマ区切りで入力（デフォルト: production）'
        if ([string]::IsNullOrWhiteSpace($prompt)) {
            return @('production')
        }

        $resolved = $prompt -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    if (-not ($resolved -contains 'production')) {
        $resolved = @('production') + $resolved
    }

    return $resolved | Select-Object -Unique
}

function Get-ScriptIdFromClaspJson {
    $claspPath = Join-Path (Get-Location) '.clasp.json'
    if (-not (Test-Path $claspPath)) {
        return $null
    }

    try {
        $json = Get-Content -Path $claspPath -Raw | ConvertFrom-Json
        if ($json.scriptId) {
            return [string]$json.scriptId
        }
    } catch {
        return $null
    }

    return $null
}

function Get-MinifiedClaspCredentialsJson {
    $clasprcPath = Join-Path $HOME '.clasprc.json'
    if (-not (Test-Path $clasprcPath)) {
        return $null
    }

    try {
        $raw = Get-Content -Path $clasprcPath -Raw
        return (ConvertFrom-Json $raw | ConvertTo-Json -Depth 100 -Compress)
    } catch {
        throw "${clasprcPath} の JSON 変換に失敗しました: $($_.Exception.Message)"
    }
}

function Invoke-GhSecretSet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryName,
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,
        [Parameter(Mandatory = $true)]
        [string]$SecretName,
        [Parameter(Mandatory = $true)]
        [string]$SecretValue
    )

    & gh secret set $SecretName --repo $RepositoryName --env $EnvironmentName --body $SecretValue | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "$SecretName の登録に失敗しました: $EnvironmentName"
    }
}

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS GitHub Environments secret 登録' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host 'gh CLI が見つかりません。GitHub CLI をインストールしてから再実行してください。' -ForegroundColor Red
    pause
    exit 1
}

try {
    & gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'gh CLI に GitHub 認証が見つかりません。`gh auth login` を実行してから再試行してください。' -ForegroundColor Red
        pause
        exit 1
    }
} catch {
    Write-Host 'gh CLI の認証確認に失敗しました。' -ForegroundColor Red
    pause
    exit 1
}

$resolvedRepository = Resolve-GitHubRepositoryName -RepositoryInput $Repository -RepositoryUrlInput $RepositoryUrl
$resolvedEnvironmentNames = Get-EnvironmentNames -InputNames $EnvironmentNames

if ([string]::IsNullOrWhiteSpace($ScriptId)) {
    $scriptIdFromClasp = Get-ScriptIdFromClaspJson
    if (-not [string]::IsNullOrWhiteSpace($scriptIdFromClasp)) {
        $ScriptId = $scriptIdFromClasp
    } else {
        $ScriptId = Read-Host 'CLASP_SCRIPT_ID を入力'
    }
}

if ([string]::IsNullOrWhiteSpace($ScriptId)) {
    Write-Host 'CLASP_SCRIPT_ID が未入力です。' -ForegroundColor Red
    pause
    exit 1
}

if ([string]::IsNullOrWhiteSpace($DeploymentId)) {
    $DeploymentId = Read-Host 'CLASP_DEPLOYMENT_ID を入力（未設定ならEnter）'
}

$credentialsJson = Get-MinifiedClaspCredentialsJson
if ([string]::IsNullOrWhiteSpace($credentialsJson)) {
    Write-Host '`.clasprc.json` が見つからないため、CLASP_CREDENTIALS_JSON は登録しません。' -ForegroundColor Yellow
}

Write-Section "対象 repository: $resolvedRepository"
Write-Host "対象 environment: $($resolvedEnvironmentNames -join ', ')" -ForegroundColor White
Write-Host ''

foreach ($environmentName in $resolvedEnvironmentNames) {
    Write-Host "environment '$environmentName' に secret を登録しています..." -ForegroundColor Cyan

    if (-not [string]::IsNullOrWhiteSpace($credentialsJson)) {
        Invoke-GhSecretSet -RepositoryName $resolvedRepository -EnvironmentName $environmentName -SecretName 'CLASP_CREDENTIALS_JSON' -SecretValue $credentialsJson
    }

    Invoke-GhSecretSet -RepositoryName $resolvedRepository -EnvironmentName $environmentName -SecretName 'CLASP_SCRIPT_ID' -SecretValue $ScriptId

    if (-not [string]::IsNullOrWhiteSpace($DeploymentId)) {
        Invoke-GhSecretSet -RepositoryName $resolvedRepository -EnvironmentName $environmentName -SecretName 'CLASP_DEPLOYMENT_ID' -SecretValue $DeploymentId
    }

    Write-Host "✓ secret 登録完了: $environmentName" -ForegroundColor Green
}

Write-Host ''
Write-Host '================================' -ForegroundColor Green
Write-Host '✓ secret 登録が完了しました！' -ForegroundColor Green
Write-Host '================================' -ForegroundColor Green
Write-Host ''
Write-Host 'このウィンドウを閉じるには、任意のキーを押してください...' -ForegroundColor Gray
[void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
