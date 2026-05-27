param(
    [Parameter(Mandatory = $true)][string]$RepoUrl,
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [string]$Branch = "dev"
)

if (Test-Path -Path $RepoPath) {
    throw "RepoPath already exists: $RepoPath. Use deploy.ps1 to update."
}

$parent = Split-Path -Parent $RepoPath
if (![string]::IsNullOrEmpty($parent) -and !(Test-Path $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

Write-Host "Cloning $RepoUrl into $RepoPath (branch: $Branch)..."
git clone --branch $Branch $RepoUrl $RepoPath
if ($LASTEXITCODE -ne 0) {
    throw "git clone failed with exit code $LASTEXITCODE"
}

Write-Host "Clone complete. Use deploy.ps1 to push updates to the Arma profile."
