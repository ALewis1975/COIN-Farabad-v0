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

robocopy $RepoMissionPath $ArmaMissionPath /MIR /R:2 /W:1 /NFL /NDL /NP /XD .git .github docs tests .vscode
if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

$verifiedFiles = @(
    "description.ext",
    "mission.sqm",
    "initServer.sqf",
    "config/CfgFunctions.hpp",
    "config/CfgRemoteExec.hpp",

    "functions/core/fn_intelBroadcast.sqf",
    "functions/core/fn_rpcValidateSender.sqf",
    "functions/core/fn_tocRequestNextIncident.sqf",
    "functions/ui/fn_uiConsoleActionRequestNextIncident.sqf",
    "functions/core/fn_taskCreateIncident.sqf",
    "functions/core/fn_taskRehydrateActive.sqf",

    "functions/ambiance/fn_airbaseInit.sqf",
    "functions/ambiance/fn_airbaseTick.sqf",
    "functions/ambiance/fn_airbasePlaneDepart.sqf",
    "functions/ambiance/fn_airbaseSpawnArrival.sqf",

    "data\incident_markers.sqf",
    "data\ARC_ConfigData.sqf"
)

$pathDir = Join-Path $RepoMissionPath "data\paths"
if (Test-Path -Path $pathDir) {
    $pathFiles = Get-ChildItem -Path $pathDir -Filter "*.sqf" -File
    foreach ($f in $pathFiles) {
        $verifiedFiles += $f.FullName.Substring($RepoMissionPath.Length + 1)
    }
}

$verifiedFiles = $verifiedFiles | Sort-Object -Unique

$mismatches = @()
foreach ($rel in $verifiedFiles) {
    $repoFile = Join-Path $RepoMissionPath $rel
    $armaFile = Join-Path $ArmaMissionPath $rel

    if (!(Test-Path -Path $repoFile)) {
        Write-Host "SKIP (missing in repo): $rel"
        continue
    }
    if (!(Test-Path -Path $armaFile)) {
        $mismatches += "$rel (missing in arma profile after sync)"
        continue
    }

    $repoHash = (Get-FileHash -Algorithm SHA256 -Path $repoFile).Hash
    $armaHash = (Get-FileHash -Algorithm SHA256 -Path $armaFile).Hash

    Write-Host "repo $rel sha256: $repoHash"
    Write-Host "arma $rel sha256: $armaHash"

    if ($repoHash -ne $armaHash) {
        $mismatches += $rel
    }
}

if ($mismatches.Count -gt 0) {
    throw "SYNC MISMATCH after copy for: $($mismatches -join ', ')"
}

Write-Host "SYNC OK: mission profile copy matches repo for $($verifiedFiles.Count) security-critical files."
