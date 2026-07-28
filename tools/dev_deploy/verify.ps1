param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$ArmaMissionPath
)

$ErrorActionPreference = "Stop"
$manifestPath = Join-Path $ArmaMissionPath "ARC_DeploymentManifest.json"
if (!(Test-Path -LiteralPath $RepoPath)) { throw "RepoPath not found: $RepoPath" }
if (!(Test-Path -LiteralPath $manifestPath)) { throw "Deployment manifest missing: $manifestPath. Run deploy.ps1 first." }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) { throw "Unsupported deployment manifest schema: $($manifest.schemaVersion)" }

Push-Location $RepoPath
try {
    $headFull = (git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $headFull -ne $manifest.sourceCommit) {
        throw "Repository HEAD does not match deployed candidate: repo=$headFull deployed=$($manifest.sourceCommit)"
    }
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne $manifest.sourceBranch) {
        throw "Repository branch does not match deployed candidate: repo=$branch deployed=$($manifest.sourceBranch)"
    }
    $dirty = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) {
        throw "Repository is dirty; deployment verification is not trustworthy: $($dirty -join '; ')"
    }

    $sync = Join-Path $RepoPath "tools/sync_mission_to_arma_profile.ps1"
    & $sync -RepoMissionPath $RepoPath -ArmaMissionPath $ArmaMissionPath -VerifyOnly `
        -ExpectedBuildStamp $manifest.buildStamp -ExpectedStampedInitServerHash $manifest.deployedInitServerSha256

    Write-Host "VERIFY OK: deployed mission matches $($manifest.sourceCommit) ($($manifest.sourceBranch))."
    Write-Host "Build stamp: $($manifest.buildStamp)"
    Write-Host "Mod preset: $($manifest.modPresetId)"
}
finally { Pop-Location }
