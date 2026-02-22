param(
    [Parameter(Mandatory = $true)]
    [string]$RepoMissionPath,

    [Parameter(Mandatory = $true)]
    [string]$ArmaMissionPath
)

if (!(Test-Path -Path $RepoMissionPath)) {
    throw "Repo mission path not found: $RepoMissionPath"
}

New-Item -ItemType Directory -Force -Path $ArmaMissionPath | Out-Null

robocopy $RepoMissionPath $ArmaMissionPath /MIR /R:2 /W:1 /NFL /NDL /NP /XD .git .github docs data tests .vscode
if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

$repoFile = Join-Path $RepoMissionPath "functions/core/fn_intelBroadcast.sqf"
$armaFile = Join-Path $ArmaMissionPath "functions/core/fn_intelBroadcast.sqf"

$repoHash = (Get-FileHash -Algorithm SHA256 -Path $repoFile).Hash
$armaHash = (Get-FileHash -Algorithm SHA256 -Path $armaFile).Hash

Write-Host "repo fn_intelBroadcast.sqf sha256: $repoHash"
Write-Host "arma fn_intelBroadcast.sqf sha256: $armaHash"

if ($repoHash -ne $armaHash) {
    throw "SYNC MISMATCH: fn_intelBroadcast.sqf differs after copy"
}

Write-Host "SYNC OK: mission profile copy matches repo for fn_intelBroadcast.sqf"
