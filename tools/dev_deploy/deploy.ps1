param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$ArmaMissionPath,
    [Parameter(Mandatory = $true)][string]$Branch,
    [string]$ModPresetId = "UNSPECIFIED",
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
if (!(Test-Path -LiteralPath $RepoPath)) { throw "RepoPath not found: $RepoPath. Run clone.ps1 first." }
foreach ($token in @(@("Branch", $Branch), @("ModPresetId", $ModPresetId))) {
    if ([string]::IsNullOrWhiteSpace($token[1]) -or $token[1].IndexOfAny(@([char]'"', [char]'|', [char]13, [char]10)) -ge 0) {
        throw "$($token[0]) cannot be embedded safely in ARC_buildStamp: $($token[1])"
    }
}

Push-Location $RepoPath
try {
    if (-not $SkipPull) {
        git fetch --all; if ($LASTEXITCODE -ne 0) { throw "git fetch failed: $LASTEXITCODE" }
        git checkout $Branch; if ($LASTEXITCODE -ne 0) { throw "git checkout failed: $LASTEXITCODE" }
        git pull --ff-only; if ($LASTEXITCODE -ne 0) { throw "git pull failed: $LASTEXITCODE" }
    }

    $actualBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualBranch -ne $Branch) { throw "Branch mismatch: requested=$Branch actual=$actualBranch" }
    $dirty = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw "Repository must be clean before deployment: $($dirty -join '; ')" }

    $headFull = (git rev-parse HEAD).Trim(); if ($LASTEXITCODE -ne 0) { throw "git rev-parse HEAD failed" }
    $headShort = (git rev-parse --short=12 HEAD).Trim(); if ($LASTEXITCODE -ne 0) { throw "git short SHA failed" }
    $sourceRemote = (git config --get remote.origin.url).Trim(); if ($LASTEXITCODE -ne 0) { throw "git remote lookup failed" }
    $builtAtUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $stamp = "COIN_Farabad_v0.Farabad|branch=$actualBranch|builtUtc=$builtAtUtc|sha=$headShort|mod=$ModPresetId"

    $sync = Join-Path $RepoPath "tools/sync_mission_to_arma_profile.ps1"
    & $sync -RepoMissionPath $RepoPath -ArmaMissionPath $ArmaMissionPath

    $sourceInit = Join-Path $RepoPath "initServer.sqf"
    $deployedInit = Join-Path $ArmaMissionPath "initServer.sqf"
    $initText = Get-Content -Raw -LiteralPath $deployedInit
    $stampPattern = 'missionNamespace setVariable \["ARC_buildStamp", "[^"]*", true\];'
    if ([regex]::Matches($initText, $stampPattern).Count -ne 1) { throw "Expected one ARC_buildStamp assignment in deployed initServer.sqf." }
    $stampLine = 'missionNamespace setVariable ["ARC_buildStamp", "' + $stamp + '", true];'
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($deployedInit, [regex]::Replace($initText, $stampPattern, $stampLine, 1), $utf8NoBom)

    $sourceInitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceInit).Hash
    $deployedInitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $deployedInit).Hash
    $manifest = [ordered]@{
        schemaVersion = 1; mission = "COIN_Farabad_v0.Farabad"; sourceCommit = $headFull
        sourceCommitShort = $headShort; sourceBranch = $actualBranch; builtAtUtc = $builtAtUtc
        modPresetId = $ModPresetId; sourceRemote = $sourceRemote; sourceClean = $true
        sourceInitServerSha256 = $sourceInitHash; deployedInitServerSha256 = $deployedInitHash; buildStamp = $stamp
    }
    $manifestPath = Join-Path $ArmaMissionPath "ARC_DeploymentManifest.json"
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 4), $utf8NoBom)

    & $sync -RepoMissionPath $RepoPath -ArmaMissionPath $ArmaMissionPath -VerifyOnly `
        -ExpectedBuildStamp $stamp -ExpectedStampedInitServerHash $deployedInitHash

    $dirtyAfter = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0 -or $dirtyAfter.Count -gt 0) { throw "Deployment changed the repository working tree: $($dirtyAfter -join '; ')" }
    Write-Host "Build stamp: $stamp"
    Write-Host "Deployment manifest: $manifestPath"
    Write-Host "DEPLOY OK: commit $headFull deployed to $ArmaMissionPath"
}
finally { Pop-Location }
