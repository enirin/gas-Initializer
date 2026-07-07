# Windows Initial GAS Project Setup Script
# Interactive steps:
# 1. Create working folder
# 2. Run clasp clone
# 3. Copy GitHub Actions workflow from artifacts
# 4. Initialize git and first commit
# 5. Push develop/main branches
# 6. Optionally register GitHub Environment secrets

$ErrorActionPreference = 'Continue'

# On PowerShell 7+, do not promote native stderr to PowerShell errors.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ''
}

function Copy-ArtifactFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    if (-not (Test-Path $SourceRoot)) {
        throw "Artifacts folder was not found: $SourceRoot"
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
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "JSON file was not found: $Path"
    }

    $raw = Get-Content -Path $Path -Raw
    return (ConvertFrom-Json $raw | ConvertTo-Json -Depth 100 -Compress)
}

function Get-GitHubRepositoryName {
    param([Parameter(Mandatory = $true)][string]$RepositoryUrl)

    $normalized = $RepositoryUrl.Trim()
    if ($normalized -match '(?:https?://|ssh://)?(?:git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
        return "$($Matches.owner)/$($Matches.repo)"
    }

    throw "Could not parse owner/repo from URL: $RepositoryUrl"
}

function Test-GitRemoteAccess {
    param([Parameter(Mandatory = $true)][string]$RepositoryUrl)

    & git ls-remote $RepositoryUrl HEAD 1>$null 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-SecretRegistration {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string[]]$EnvironmentNames,
        [Parameter(Mandatory = $true)][string]$ScriptId,
        [string]$DeploymentId
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host 'gh CLI was not found. Skipping secret registration.' -ForegroundColor Yellow
        return
    }

    try {
        & gh auth status 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'gh auth is not ready. Run: gh auth login' -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host 'Failed to verify gh auth status. Skipping secret registration.' -ForegroundColor Yellow
        return
    }

    $clasprcPath = Join-Path $HOME '.clasprc.json'
    if (-not (Test-Path $clasprcPath)) {
        Write-Host "$clasprcPath was not found. CLASP_CREDENTIALS_JSON will be skipped." -ForegroundColor Yellow
        $credentialsJson = $null
    } else {
        $credentialsJson = ConvertTo-MinifiedJson -Path $clasprcPath
    }

    foreach ($environmentName in $EnvironmentNames) {
        $envName = $environmentName.Trim()
        if ([string]::IsNullOrWhiteSpace($envName)) {
            continue
        }

        Write-Host "Registering secrets for environment '$envName'..." -ForegroundColor Cyan

        if ($credentialsJson) {
            & gh secret set CLASP_CREDENTIALS_JSON --repo $Repository --env $envName --body $credentialsJson | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set CLASP_CREDENTIALS_JSON for $envName"
            }
        }

        & gh secret set CLASP_SCRIPT_ID --repo $Repository --env $envName --body $ScriptId | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set CLASP_SCRIPT_ID for $envName"
        }

        if (-not [string]::IsNullOrWhiteSpace($DeploymentId)) {
            & gh secret set CLASP_DEPLOYMENT_ID --repo $Repository --env $envName --body $DeploymentId | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set CLASP_DEPLOYMENT_ID for $envName"
            }
        }

        Write-Host "Secret registration completed: $envName" -ForegroundColor Green
    }
}

Write-Host '================================' -ForegroundColor Cyan
Write-Host 'GAS project initializer' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

Write-Section 'Step 1: Create working folder'

$defaultPath = [Environment]::GetFolderPath('Desktop')
Write-Host 'Enter a parent folder path for the project.' -ForegroundColor White
Write-Host "Default: $defaultPath" -ForegroundColor Gray
Write-Host ''
$folderPath = Read-Host 'Folder path (press Enter for default)'
if ([string]::IsNullOrWhiteSpace($folderPath)) {
    $folderPath = $defaultPath
}

$folderName = Read-Host 'Folder name (default: production-portal)'
if ([string]::IsNullOrWhiteSpace($folderName)) {
    $folderName = 'production-portal'
}

$fullPath = Join-Path $folderPath $folderName

if (Test-Path $fullPath) {
    Write-Host "Warning: '$fullPath' already exists." -ForegroundColor Red
    $confirm = Read-Host 'Use this folder? (y/n)'
    if ($confirm -ne 'y') {
        Write-Host 'Canceled.' -ForegroundColor Red
        exit 1
    }
} else {
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    Write-Host "Folder created: $fullPath" -ForegroundColor Green
}

Write-Host ''
Write-Section 'Step 2: Run clasp clone'

Write-Host 'Get script ID from Apps Script editor and paste it below.' -ForegroundColor White
$scriptId = Read-Host 'Script ID'
if ([string]::IsNullOrWhiteSpace($scriptId)) {
    Write-Host 'Script ID is required.' -ForegroundColor Red
    pause
    exit 1
}

Write-Section 'Step 3: Copy GitHub Actions workflow'
$artifactWorkflowRoot = Join-Path $PSScriptRoot 'artifacts\.github\workflows'
$targetWorkflowRoot = Join-Path $fullPath '.github\workflows'
try {
    Copy-ArtifactFiles -SourceRoot $artifactWorkflowRoot -DestinationRoot $targetWorkflowRoot
    Write-Host 'Workflow files copied.' -ForegroundColor Green
} catch {
    Write-Host "Failed to copy workflow files: $_" -ForegroundColor Red
    pause
    exit 1
}

Set-Location $fullPath
Write-Host 'Running clasp clone...' -ForegroundColor Cyan
$cloneOutput = (& clasp clone $scriptId 2>&1 | Out-String)
if ($cloneOutput -match '(?i)invalid script id') {
    Write-Host 'clasp clone reported Invalid script ID. Verify the Script ID and access permission.' -ForegroundColor Red
    pause
    exit 1
}

if ($LASTEXITCODE -ne 0) {
    Write-Host 'clasp clone failed. Make sure clasp is installed and logged in.' -ForegroundColor Red
    pause
    exit 1
}

$claspConfigPath = Join-Path $fullPath '.clasp.json'
if (-not (Test-Path $claspConfigPath)) {
    Write-Host '.clasp.json was not created by clasp clone. Clone likely failed.' -ForegroundColor Red
    pause
    exit 1
}

Write-Host 'Running clasp pull to ensure latest server files are downloaded...' -ForegroundColor Cyan
& clasp pull 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host 'clasp pull failed after clone. Check script ID and your access permission.' -ForegroundColor Red
    pause
    exit 1
}

$manifestPath = Join-Path $fullPath 'appsscript.json'
if (-not (Test-Path $manifestPath)) {
    Write-Host 'Clone completed but appsscript.json was not found. The script ID may be wrong or inaccessible.' -ForegroundColor Red
    pause
    exit 1
}

$scriptFiles = Get-ChildItem -Path $fullPath -File -Include *.gs,*.js,*.ts,*.html
if ($scriptFiles.Count -eq 0) {
    Write-Host 'Clone completed and manifest downloaded, but no script files were found (.gs/.js/.ts/.html).' -ForegroundColor Yellow
    Write-Host 'Possible reasons: project has only manifest, no source files, or wrong script ID.' -ForegroundColor Yellow
} else {
    Write-Host "Downloaded script files: $($scriptFiles.Count)" -ForegroundColor Green
}

Write-Host 'clasp clone completed.' -ForegroundColor Green

Write-Host ''
Write-Section 'Step 4: Initialize git'

& git init 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git init failed' }

& git checkout -b develop 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'failed to create develop branch' }

Write-Host 'Git initialized.' -ForegroundColor Green

Write-Host ''
Write-Section 'Step 5: Configure remote'

$repoUrl = ''
while ($true) {
    $repoUrl = Read-Host 'Repository URL (example: https://github.com/enirin/production-portal.git)'
    if ([string]::IsNullOrWhiteSpace($repoUrl)) {
        Write-Host 'Repository URL is required.' -ForegroundColor Red
        continue
    }

    $repoUrl = $repoUrl.Trim().TrimEnd('/')
    if (Test-GitRemoteAccess -RepositoryUrl $repoUrl) {
        break
    }

    Write-Host 'Could not access the repository. Check URL and your GitHub permission.' -ForegroundColor Red
    Write-Host 'If this repository is private, make sure git authentication is configured.' -ForegroundColor Yellow
    $retryRemote = Read-Host 'Retry repository URL input? (y/n, default: y)'
    if (-not [string]::IsNullOrWhiteSpace($retryRemote) -and $retryRemote -notmatch '^[yY]') {
        exit 1
    }
}

& git remote add origin $repoUrl 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Failed to add remote origin.' -ForegroundColor Red
    pause
    exit 1
}
Write-Host 'Remote origin configured.' -ForegroundColor Green

Write-Host ''
Write-Section 'Step 6: First commit'

& git add . 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

$commitMsg = 'chore: initial GAS resource import'
& git commit -m $commitMsg 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'git commit failed.' -ForegroundColor Red
    pause
    exit 1
}
Write-Host 'First commit completed.' -ForegroundColor Green

Write-Host ''
Write-Section 'Step 7: Push branches'

& git push -u origin develop 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Failed to push develop. Please push manually.' -ForegroundColor Red
    Write-Host "Remote URL: $repoUrl" -ForegroundColor Yellow
    Write-Host 'Hint: Verify repository exists and your authentication has access.' -ForegroundColor Yellow
} else {
    & git checkout -b main 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & git push -u origin main 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Failed to push main. Please push manually.' -ForegroundColor Red
        }
        & git checkout develop 2>&1 | Out-Null
    }
    Write-Host 'Branch push step finished.' -ForegroundColor Green
}

Write-Host ''
Write-Section 'Step 8: Register GitHub Environment secrets (optional)'

$registerSecrets = Read-Host 'Register secrets now? (y/n, default: y)'
if ([string]::IsNullOrWhiteSpace($registerSecrets) -or $registerSecrets -match '^[yY]') {
    $environmentInput = Read-Host 'Target environments (comma-separated, default: production)'
    if ([string]::IsNullOrWhiteSpace($environmentInput)) {
        $environmentNames = @('production')
    } else {
        $environmentNames = $environmentInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if (-not ($environmentNames -contains 'production')) {
            $environmentNames = @('production') + $environmentNames
        }
    }

    $claspDeploymentId = Read-Host 'CLASP_DEPLOYMENT_ID (optional)'

    try {
        $repositoryName = Get-GitHubRepositoryName -RepositoryUrl $repoUrl
        Invoke-SecretRegistration -Repository $repositoryName -EnvironmentNames $environmentNames -ScriptId $scriptId -DeploymentId $claspDeploymentId
    } catch {
        Write-Host "Secret registration failed: $_" -ForegroundColor Red
        Write-Host 'You can run register-gas-environment-secrets.ps1 later.' -ForegroundColor Yellow
    }
} else {
    Write-Host 'Secret registration skipped.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '================================' -ForegroundColor Green
Write-Host 'Project initialization completed.' -ForegroundColor Green
Write-Host '================================' -ForegroundColor Green
Write-Host ''
Write-Host "1) Open folder in VS Code: $fullPath" -ForegroundColor White
Write-Host '2) Verify environment secrets in GitHub settings' -ForegroundColor White
Write-Host '3) Start development' -ForegroundColor White
Write-Host ''
Write-Host 'Press any key to close this window...' -ForegroundColor Gray
[void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
