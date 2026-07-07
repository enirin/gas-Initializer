# Register GitHub Environment secrets for GAS / clasp
# - CLASP_CREDENTIALS_JSON
# - CLASP_SCRIPT_ID
# - CLASP_DEPLOYMENT_ID (optional)

param(
    [string]$ProjectPath,
    [string[]]$EnvironmentNames,
    [string]$Repository,
    [string]$RepositoryUrl,
    [string]$ScriptId,
    [string]$DeploymentId
)

$ErrorActionPreference = 'Stop'

# If ProjectPath is not specified, prompt user
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    Write-Host 'Project Folder Setup' -ForegroundColor Yellow
    Write-Host ''
    $ProjectPath = Read-Host 'Enter project folder path (where .clasp.json exists)'
}

# Validate ProjectPath exists
if (-not (Test-Path $ProjectPath -PathType Container)) {
    Write-Host "Project folder not found: ${ProjectPath}" -ForegroundColor Red
    pause
    exit 1
}

# If Repository and RepositoryUrl are not specified, prompt user
if ([string]::IsNullOrWhiteSpace($Repository) -and [string]::IsNullOrWhiteSpace($RepositoryUrl)) {
    Write-Host 'GitHub Repository Setup' -ForegroundColor Yellow
    Write-Host ''
    $Repository = Read-Host 'Enter repository (owner/repo or URL)'
}

# If EnvironmentNames are not specified, prompt user
if ($EnvironmentNames.Count -eq 0 -or [string]::IsNullOrWhiteSpace($EnvironmentNames[0])) {
    $envInput = Read-Host 'Enter environment name(s) separated by comma (default: production)'
    if ([string]::IsNullOrWhiteSpace($envInput)) {
        $EnvironmentNames = @('production')
    } else {
        $EnvironmentNames = $envInput -split ',' | ForEach-Object { $_.Trim() }
    }
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Message)
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
        # continue
    }

    throw 'Could not resolve repository name. Use -Repository or -RepositoryUrl.'
}

function Get-EnvironmentNames {
    param([string[]]$InputNames)

    $resolved = @()
    foreach ($name in $InputNames) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $resolved += ($name -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    if ($resolved.Count -eq 0) {
        $prompt = Read-Host 'Target environments (comma-separated, default: production)'
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
    param([string]$ProjectPath)

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectPath = Get-Location
    }

    $claspPath = Join-Path $ProjectPath '.clasp.json'
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
        throw "Failed to parse ${clasprcPath}: $($_.Exception.Message)"
    }
}

function Invoke-GhSecretSet {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryName,
        [Parameter(Mandatory = $true)][string]$EnvironmentName,
        [Parameter(Mandatory = $true)][string]$SecretName,
        [Parameter(Mandatory = $true)][string]$SecretValue
    )

    if ($SecretName -eq 'CLASP_CREDENTIALS_JSON') {
        # JSON is already minified; pass as --body to avoid stdin formatting side effects.
        & gh secret set $SecretName --repo $RepositoryName --env $EnvironmentName --body "$SecretValue" 2>&1 | Out-Null
    } else {
        $SecretValue | & gh secret set $SecretName --repo $RepositoryName --env $EnvironmentName 2>&1 | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set $SecretName for $EnvironmentName"
    }
}

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS environment secret registration' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host 'gh CLI was not found. Install GitHub CLI and retry.' -ForegroundColor Red
    pause
    exit 1
}

try {
    & gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'gh auth is not ready. Run: gh auth login' -ForegroundColor Red
        pause
        exit 1
    }
} catch {
    Write-Host 'Failed to verify gh auth status.' -ForegroundColor Red
    pause
    exit 1
}

try {
    $resolvedRepository = Resolve-GitHubRepositoryName -RepositoryInput $Repository -RepositoryUrlInput $RepositoryUrl
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    pause
    exit 1
}

$resolvedEnvironmentNames = Get-EnvironmentNames -InputNames $EnvironmentNames

if ([string]::IsNullOrWhiteSpace($ScriptId)) {
    $scriptIdFromClasp = Get-ScriptIdFromClaspJson -ProjectPath $ProjectPath
    if (-not [string]::IsNullOrWhiteSpace($scriptIdFromClasp)) {
        $ScriptId = $scriptIdFromClasp
    } else {
        $ScriptId = Read-Host 'CLASP_SCRIPT_ID'
    }
}

if ([string]::IsNullOrWhiteSpace($ScriptId)) {
    Write-Host 'CLASP_SCRIPT_ID is required.' -ForegroundColor Red
    pause
    exit 1
}

if ([string]::IsNullOrWhiteSpace($DeploymentId)) {
    $DeploymentId = Read-Host 'CLASP_DEPLOYMENT_ID (optional)'
}

$credentialsJson = Get-MinifiedClaspCredentialsJson
if ([string]::IsNullOrWhiteSpace($credentialsJson)) {
    Write-Host '.clasprc.json was not found. CLASP_CREDENTIALS_JSON will be skipped.' -ForegroundColor Yellow
}

Write-Section "Target repository: $resolvedRepository"
Write-Host "Target environments: $($resolvedEnvironmentNames -join ', ')" -ForegroundColor White
Write-Host ''

foreach ($environmentName in $resolvedEnvironmentNames) {
    Write-Host "Registering secrets for environment '$environmentName'..." -ForegroundColor Cyan

    if (-not [string]::IsNullOrWhiteSpace($credentialsJson)) {
        Invoke-GhSecretSet -RepositoryName $resolvedRepository -EnvironmentName $environmentName -SecretName 'CLASP_CREDENTIALS_JSON' -SecretValue $credentialsJson
    }

    Invoke-GhSecretSet -RepositoryName $resolvedRepository -EnvironmentName $environmentName -SecretName 'CLASP_SCRIPT_ID' -SecretValue $ScriptId

    if (-not [string]::IsNullOrWhiteSpace($DeploymentId)) {
        Invoke-GhSecretSet -RepositoryName $resolvedRepository -EnvironmentName $environmentName -SecretName 'CLASP_DEPLOYMENT_ID' -SecretValue $DeploymentId
    }

    Write-Host "Secret registration completed: $environmentName" -ForegroundColor Green
}

Write-Host ''
Write-Host '================================' -ForegroundColor Green
Write-Host 'Secret registration completed.' -ForegroundColor Green
Write-Host '================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Press any key to close this window...' -ForegroundColor Gray
[void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
