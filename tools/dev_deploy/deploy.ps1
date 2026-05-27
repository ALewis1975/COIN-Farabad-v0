param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$ArmaMissionPath,
    [string]$Branch = "dev",
    [switch]$SkipPull
)

if (!(Test-Path -Path $RepoPath)) {
    throw "RepoPath not found: $RepoPath. Run clone.ps1 first."
}

Push-Location $RepoPath
try {
    if (-not $SkipPull) {
        Write-Host "git fetch + checkout $Branch + pull..."
        git fetch --all
        if ($LASTEXITCODE -ne 0) { throw "git fetch failed: $LASTEXITCODE" }

        git checkout $Branch
        if ($LASTEXITCODE -ne 0) { throw "git checkout failed: $LASTEXITCODE" }

        git pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull failed: $LASTEXITCODE" }
    }

    $head = (git rev-parse --short HEAD).Trim()
    Write-Host "HEAD: $head"

    $sync = Join-Path $RepoPath "tools/sync_mission_to_arma_profile.ps1"
    if (!(Test-Path $sync)) { throw "sync script missing: $sync" }

    Write-Host "Syncing $RepoPath -> $ArmaMissionPath ..."
    & $sync -RepoMissionPath $RepoPath -ArmaMissionPath $ArmaMissionPath
    if ($LASTEXITCODE -ne 0) { throw "sync failed: $LASTEXITCODE" }

    Write-Host "DEPLOY OK: $head deployed to $ArmaMissionPath"
}
finally {
    Pop-Location
}
