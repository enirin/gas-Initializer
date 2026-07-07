# Windows Initial GAS Project Setup Script
# このスクリプトは以下を対話的に行います:
# 1. 開発フォルダの作成
# 2. clasp cloneの実行
# 3. GitHub Actions 用 workflow の配置
# 4. git初期化と初回コミット
# 5. develop/mainブランチの作成とプッシュ
# 6. GitHub Environments の secret 登録

$ErrorActionPreference = "Stop"

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""
}

function Copy-ArtifactFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    if (-not (Test-Path $SourceRoot)) {
        throw "artifacts フォルダが見つかりません: $SourceRoot"
    }

    $files = Get-ChildItem -Path $SourceRoot -Recurse -File | Where-Object { $_.Name -notlike '*:Zone.Identifier' }

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($SourceRoot.Length).TrimStart('\', '/')
        $destinationPath = Join-Path $DestinationRoot $relativePath
        $destinationDir = Split-Path $destinationPath -Parent

        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        Copy-Item -Path $file.FullName -Destination $destinationPath -Force
    }
}

function ConvertTo-MinifiedJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "JSON ファイルが見つかりません: $Path"
    }

    $raw = Get-Content -Path $Path -Raw
    return (ConvertFrom-Json $raw | ConvertTo-Json -Depth 100 -Compress)
}

function Get-GitHubRepositoryName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryUrl
    )

    $normalized = $RepositoryUrl.Trim()
    if ($normalized -match '(?:https?://|ssh://)?(?:git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
        return "$($Matches.owner)/$($Matches.repo)"
    }

    throw "GitHub リポジトリ URL から owner/name を解析できませんでした: $RepositoryUrl"
}

function Invoke-SecretRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        [Parameter(Mandatory = $true)]
        [string[]]$EnvironmentNames,
        [Parameter(Mandatory = $true)]
        [string]$ScriptId,
        [string]$DeploymentId
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "gh CLI が見つからないため、GitHub Environments の secret 登録はスキップします。" -ForegroundColor Yellow
        return
    }

    try {
        & gh auth status 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "gh CLI に GitHub 認証が見つかりません。`gh auth login` 後に secret を登録してください。" -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host "gh CLI の認証状態確認に失敗したため、secret 登録はスキップします。" -ForegroundColor Yellow
        return
    }

    $clasprcPath = Join-Path $HOME '.clasprc.json'
    if (-not (Test-Path $clasprcPath)) {
        Write-Host "${clasprcPath} が見つからないため、CLASP_CREDENTIALS_JSON は登録できません。" -ForegroundColor Yellow
        $credentialsJson = $null
    } else {
        $credentialsJson = ConvertTo-MinifiedJson -Path $clasprcPath
    }

    foreach ($environmentName in $EnvironmentNames) {
        $envName = $environmentName.Trim()
        if ([string]::IsNullOrWhiteSpace($envName)) {
            continue
        }

        Write-Host "GitHub environment '$envName' に secret を登録します..." -ForegroundColor Cyan

        if ($credentialsJson) {
            & gh secret set CLASP_CREDENTIALS_JSON --repo $Repository --env $envName --body $credentialsJson | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "CLASP_CREDENTIALS_JSON の登録に失敗しました: $envName"
            }
        }

        & gh secret set CLASP_SCRIPT_ID --repo $Repository --env $envName --body $ScriptId | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "CLASP_SCRIPT_ID の登録に失敗しました: $envName"
        }

        if (-not [string]::IsNullOrWhiteSpace($DeploymentId)) {
            & gh secret set CLASP_DEPLOYMENT_ID --repo $Repository --env $envName --body $DeploymentId | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "CLASP_DEPLOYMENT_ID の登録に失敗しました: $envName"
            }
        }

        Write-Host "✓ secret 登録完了: $envName" -ForegroundColor Green
    }
}

Write-Host "================================" -ForegroundColor Cyan
Write-Host "GAS プロジェクト初期化スクリプト" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 1. フォルダ作成
Write-Host "ステップ1: 開発用フォルダーの作成" -ForegroundColor Yellow
Write-Host ""

$defaultPath = [Environment]::GetFolderPath('Desktop')
Write-Host "フォルダを作成する場所を指定してください。" -ForegroundColor White
Write-Host "デフォルト: $defaultPath" -ForegroundColor Gray
Write-Host ""
$folderPath = Read-Host "フォルダのパス（デフォルトはEnterのみ）"

if ([string]::IsNullOrWhiteSpace($folderPath)) {
    $folderPath = $defaultPath
}

$folderName = Read-Host "フォルダ名を入力（デフォルト: production-portal）"
if ([string]::IsNullOrWhiteSpace($folderName)) {
    $folderName = "production-portal"
}

$fullPath = Join-Path $folderPath $folderName

if (Test-Path $fullPath) {
    Write-Host "警告: フォルダ '$fullPath' は既に存在します。" -ForegroundColor Red
    $confirm = Read-Host "このフォルダを使用しますか？ (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "キャンセルしました。" -ForegroundColor Red
        exit 1
    }
} else {
    try {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "✓ フォルダを作成しました: $fullPath" -ForegroundColor Green
    } catch {
        Write-Host "✗ フォルダ作成に失敗しました: $_" -ForegroundColor Red
        pause
        exit 1
    }
}

Write-Host ""

# 2. clasp clone
Write-Host "ステップ2: clasp cloneの実行" -ForegroundColor Yellow
Write-Host ""
Write-Host "Apps Script エディタから「スクリプトID」を取得してください。" -ForegroundColor White
Write-Host "  1. ブラウザで Apps Script を開く" -ForegroundColor Gray
Write-Host "  2. 左側メニューから「プロジェクトの設定」⚙️ をクリック" -ForegroundColor Gray
Write-Host "  3. 「スクリプト ID」をコピー" -ForegroundColor Gray
Write-Host ""

$scriptId = Read-Host "スクリプトID を入力"

if ([string]::IsNullOrWhiteSpace($scriptId)) {
    Write-Host "✗ スクリプトIDが入力されていません。" -ForegroundColor Red
    pause
    exit 1
}

# 3. GitHub Actions workflow 配置
Write-Section "ステップ3: GitHub Actions workflow の配置"

$artifactWorkflowRoot = Join-Path $PSScriptRoot 'artifacts\.github\workflows'

try {
    Copy-ArtifactFiles -SourceRoot $artifactWorkflowRoot -DestinationRoot $fullPath
    Write-Host "✓ GitHub Actions workflow を配置しました。" -ForegroundColor Green
} catch {
    Write-Host "✗ GitHub Actions workflow の配置に失敗しました: $_" -ForegroundColor Red
    pause
    exit 1
}

# clasp clone実行
Write-Host ""
Write-Host "clasp cloneを実行しています..." -ForegroundColor Cyan

Set-Location $fullPath

try {
    &clasp clone $scriptId 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ clasp cloneに失敗しました。clasp がインストールされていますか？" -ForegroundColor Red
        Write-Host "  インストール方法: npm install -g @google/clasp" -ForegroundColor Gray
        pause
        exit 1
    }
    Write-Host "✓ clasp cloneが完了しました。" -ForegroundColor Green
} catch {
    Write-Host "✗ clasp clone実行中にエラーが発生しました: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""

# 4. Git初期化
Write-Host "ステップ4: Git初期化" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "git init..." -ForegroundColor Cyan
    &git init 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git init失敗" }
    
    Write-Host "git checkout -b develop..." -ForegroundColor Cyan
    &git checkout -b develop 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "develop ブランチ作成失敗" }
    
    Write-Host "✓ Gitの初期化が完了しました。" -ForegroundColor Green
} catch {
    Write-Host "✗ Git初期化に失敗しました: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""

# 5. リモートリポジトリ設定
Write-Host "ステップ5: リモートリポジトリの設定" -ForegroundColor Yellow
Write-Host ""
Write-Host "GitHub から空リポジトリのURLを取得してください。" -ForegroundColor White
Write-Host "  例: https://github.com/enirin/production-portal.git" -ForegroundColor Gray
Write-Host ""

$repoUrl = Read-Host "リポジトリURL を入力"

if ([string]::IsNullOrWhiteSpace($repoUrl)) {
    Write-Host "✗ リポジトリURLが入力されていません。" -ForegroundColor Red
    pause
    exit 1
}

try {
    Write-Host "git remote add origin $repoUrl..." -ForegroundColor Cyan
    &git remote add origin $repoUrl 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "リモート追加失敗" }
    
    Write-Host "✓ リモートリポジトリを設定しました。" -ForegroundColor Green
} catch {
    Write-Host "✗ リモート設定に失敗しました: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""

# 6. ファイル登録とコミット
Write-Host "ステップ6: ファイル登録と初回コミット" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "git add ..." -ForegroundColor Cyan
    &git add . 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git add失敗" }
    
    Write-Host "git commit..." -ForegroundColor Cyan
    $commitMsg = "chore: メンバーのGASリソースの初期インポート"
    &git commit -m $commitMsg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git commit失敗" }
    
    Write-Host "✓ 初回コミットが完了しました。" -ForegroundColor Green
} catch {
    Write-Host "✗ コミット処理に失敗しました: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""

# 7. ブランチプッシュ
Write-Host "ステップ7: GitHubへのプッシュ" -ForegroundColor Yellow
Write-Host ""
Write-Host "必要に応じてGitHubのユーザー認証が求められます。" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "git push -u origin develop..." -ForegroundColor Cyan
    &git push -u origin develop 2>&1
    if ($LASTEXITCODE -ne 0) { throw "develop ブランチプッシュ失敗" }
    
    Write-Host ""
    Write-Host "git checkout -b main..." -ForegroundColor Cyan
    &git checkout -b main 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "main ブランチ作成失敗" }
    
    Write-Host "git push -u origin main..." -ForegroundColor Cyan
    &git push -u origin main 2>&1
    if ($LASTEXITCODE -ne 0) { throw "main ブランチプッシュ失敗" }
    
    Write-Host ""
    Write-Host "git checkout develop..." -ForegroundColor Cyan
    &git checkout develop 2>&1 | Out-Null
    
    Write-Host "✓ ブランチのプッシュが完了しました。" -ForegroundColor Green
} catch {
    Write-Host "✗ プッシュ処理に失敗しました: $_" -ForegroundColor Red
    Write-Host "  手動でプッシュしてください: git push -u origin develop" -ForegroundColor Gray
}

Write-Host ""
Write-Section "ステップ8: GitHub Environments の secret 登録"
Write-Host "production environment を含む secret 登録を行います。必要に応じて追加 environment も登録できます。" -ForegroundColor White
Write-Host ""

$registerSecrets = Read-Host "secret を登録しますか？ (y/n, デフォルト: y)"
if ([string]::IsNullOrWhiteSpace($registerSecrets) -or $registerSecrets -match '^[yY]') {
    $environmentInput = Read-Host "対象 environment をカンマ区切りで入力（デフォルト: production）"
    if ([string]::IsNullOrWhiteSpace($environmentInput)) {
        $environmentNames = @('production')
    } else {
        $environmentNames = $environmentInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if (-not ($environmentNames -contains 'production')) {
            $environmentNames = @('production') + $environmentNames
        }
    }

    $claspDeploymentId = Read-Host "CLASP_DEPLOYMENT_ID を入力（未設定ならEnter）"

    try {
        $repositoryName = Get-GitHubRepositoryName -RepositoryUrl $repoUrl
        Invoke-SecretRegistration -Repository $repositoryName -EnvironmentNames $environmentNames -ScriptId $scriptId -DeploymentId $claspDeploymentId
    } catch {
        Write-Host "secret 登録に失敗しました: $_" -ForegroundColor Red
        Write-Host "後で register-gas-environment-secrets.ps1 を実行して登録してください。" -ForegroundColor Yellow
    }
} else {
    Write-Host "secret 登録はスキップされました。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✓ プロジェクト初期化が完了しました！" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "次のステップ:" -ForegroundColor Cyan
Write-Host "  1. VS Code でこのフォルダを開く: $fullPath" -ForegroundColor White
Write-Host "  2. GitHub repository settings の Environment secret を確認する" -ForegroundColor White
Write-Host "  3. コード編集を開始する" -ForegroundColor White
Write-Host ""
Write-Host "このウィンドウを閉じるには、任意のキーを押してください..." -ForegroundColor Gray
[void] $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
