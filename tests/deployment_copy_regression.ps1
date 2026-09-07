# Run on Windows. Executes the real sync tool only against an isolated temp tree.
$ErrorActionPreference = 'Stop'
$syncTool = Join-Path $PSScriptRoot '../tools/sync_mission_to_arma_profile.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('Farabad-copy-test-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'source'
$destination = Join-Path $fixture 'destination'
$passed = 0
function Assert-Case([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++
    Write-Host "PASS: $Name"
}
function Expect-Rejection([scriptblock]$Action, [string]$Name) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert-Case $rejected $Name
}
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $source 'data/docs'), (Join-Path $source 'docs'), (Join-Path $source 'tests') | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'mission.sqm') -Value 'fixture mission'
    Set-Content -LiteralPath (Join-Path $source 'data/docs/reference.txt') -Value 'nested runtime data'
    Set-Content -LiteralPath (Join-Path $source 'docs/excluded.txt') -Value 'root documentation'
    Set-Content -LiteralPath (Join-Path $source 'tests/excluded.txt') -Value 'root tests'
    & $syncTool -RepoMissionPath $source -ArmaMissionPath $destination
    Assert-Case (Test-Path -LiteralPath (Join-Path $destination 'data/docs/reference.txt')) 'fresh copy includes nested data/docs'
    Assert-Case (-not (Test-Path -LiteralPath (Join-Path $destination 'docs/excluded.txt'))) 'root docs excluded'
    Assert-Case (-not (Test-Path -LiteralPath (Join-Path $destination 'tests/excluded.txt'))) 'root tests excluded'
    Set-Content -LiteralPath (Join-Path $destination 'obsolete.txt') -Value 'old deployment'
    Set-Content -LiteralPath (Join-Path $source 'data/docs/reference.txt') -Value 'updated nested data'
    & $syncTool -RepoMissionPath $source -ArmaMissionPath $destination
    Assert-Case (-not (Test-Path -LiteralPath (Join-Path $destination 'obsolete.txt'))) 'mirror removes stale included files'
    Assert-Case ((Get-Content -Raw -LiteralPath (Join-Path $destination 'data/docs/reference.txt')) -match 'updated nested data') 'existing destination refreshes nested data'
    & $syncTool -RepoMissionPath $source -ArmaMissionPath $destination -VerifyOnly
    $passed++
    Write-Host 'PASS: unchanged copy verifies'
    Set-Content -LiteralPath (Join-Path $destination 'data/docs/reference.txt') -Value 'drift'
    Expect-Rejection { & $syncTool -RepoMissionPath $source -ArmaMissionPath $destination -VerifyOnly } 'nested data drift detected'
    Expect-Rejection { & $syncTool -RepoMissionPath $source -ArmaMissionPath $source } 'same source and destination rejected before mutation'
    Expect-Rejection { & $syncTool -RepoMissionPath $source -ArmaMissionPath (Join-Path $source 'child') } 'nested destination rejected before mutation'
    Expect-Rejection { & $syncTool -RepoMissionPath $source -ArmaMissionPath $fixture } 'ancestor destination rejected before mutation'
    Write-Host "Deployment regression: $passed PASS."
} finally {
    # Verify the exact resolved target is this test's GUID directory before recursion.
    $resolved = [IO.Path]::GetFullPath($fixture).TrimEnd('\', '/')
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if ($resolved.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and
        ([IO.Path]::GetFileName($resolved) -match '^Farabad-copy-test-[0-9a-f]{32}$')) {
        if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}
