param(
    [Parameter(Mandatory = $true)][string]$RepoMissionPath,
    [Parameter(Mandatory = $true)][string]$ArmaMissionPath,
    [switch]$VerifyOnly,
    [string]$ExpectedBuildStamp = "",
    [string]$ExpectedStampedInitServerHash = "",
    [string[]]$AllowedDestinationOnlyFiles = @("ARC_DeploymentManifest.json")
)

$ErrorActionPreference = "Stop"
$excludedPathPattern = '^(\.git|\.github|docs|tests|\.vscode)(\\|$)'

function Resolve-Root([string]$Path) {
    if (!(Test-Path -LiteralPath $Path)) { throw "Path not found: $Path" }
    (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')
}

function Get-MissionFileMap([string]$Root) {
    $map = @{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('/', '\')
        if ($rel -notmatch $excludedPathPattern) { $map[$rel] = $_.FullName }
    }
    $map
}

$repoRoot = Resolve-Root $RepoMissionPath
if (-not $VerifyOnly) {
    New-Item -ItemType Directory -Force -Path $ArmaMissionPath | Out-Null
    foreach ($rel in $AllowedDestinationOnlyFiles) {
        $generated = Join-Path $ArmaMissionPath $rel
        if (Test-Path -LiteralPath $generated) { Remove-Item -LiteralPath $generated -Force }
    }
    robocopy $repoRoot $ArmaMissionPath /MIR /R:2 /W:1 /NFL /NDL /NP /XD .git .github docs tests .vscode
    if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }
}

$armaRoot = Resolve-Root $ArmaMissionPath
$repoFiles = Get-MissionFileMap $repoRoot
$armaFiles = Get-MissionFileMap $armaRoot
$allowedExtras = @{}
$AllowedDestinationOnlyFiles | ForEach-Object { $allowedExtras[$_.Replace('/', '\')] = $true }
$mismatches = New-Object System.Collections.Generic.List[string]

foreach ($rel in ($repoFiles.Keys | Sort-Object)) {
    if (!$armaFiles.ContainsKey($rel)) {
        $mismatches.Add("$rel (missing in Arma mission copy)")
        continue
    }

    $repoFile = $repoFiles[$rel]
    $armaFile = $armaFiles[$rel]
    if (($rel -ieq "initServer.sqf") -and $ExpectedBuildStamp) {
        $expectedLine = 'missionNamespace setVariable ["ARC_buildStamp", "' + $ExpectedBuildStamp + '", true];'
        if ((Get-Content -Raw -LiteralPath $armaFile).IndexOf($expectedLine, [System.StringComparison]::Ordinal) -lt 0) {
            $mismatches.Add("initServer.sqf (expected deployment build stamp missing)")
        }
        if ($ExpectedStampedInitServerHash) {
            $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $armaFile).Hash
            if ($actualHash -ine $ExpectedStampedInitServerHash) {
                $mismatches.Add("initServer.sqf (stamped sha256 mismatch)")
            }
        }
        continue
    }

    $repoHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $repoFile).Hash
    $armaHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $armaFile).Hash
    if ($repoHash -ine $armaHash) { $mismatches.Add("$rel (sha256 mismatch)") }
}

foreach ($rel in $armaFiles.Keys) {
    if (!$repoFiles.ContainsKey($rel) -and !$allowedExtras.ContainsKey($rel)) {
        $mismatches.Add("$rel (unexpected destination-only file)")
    }
}

if ($mismatches.Count -gt 0) {
    throw "MISSION COPY VERIFY FAILED ($($mismatches.Count)): $(($mismatches | Select-Object -First 50) -join '; ')"
}

$mode = if ($VerifyOnly) { "VERIFY" } else { "SYNC" }
Write-Host "$mode OK: $($repoFiles.Count) repository mission files match $armaRoot."
