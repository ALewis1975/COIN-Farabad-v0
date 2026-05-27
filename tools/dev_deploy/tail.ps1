param(
    [Parameter(Mandatory = $true)][string]$RptPath,
    [string]$Pattern = "\[ARC\]\[SEC\]|MISSING_REMOTE_CONTEXT|SECURITY_DENIED|Error in expression|Generic error|SCRIPT \(",
    [int]$TailLines = 200
)

# Resolve the newest matching RPT if a wildcard or directory is passed.
$resolved = $RptPath
if ($RptPath -match '\*' -or (Test-Path -Path $RptPath -PathType Container)) {
    $candidates = Get-ChildItem -Path $RptPath -File -ErrorAction Stop |
                  Sort-Object LastWriteTime -Descending
    if (-not $candidates -or $candidates.Count -eq 0) {
        throw "No RPT files matched: $RptPath"
    }
    $resolved = $candidates[0].FullName
    Write-Host "Tailing newest match: $resolved"
}
elseif (!(Test-Path $resolved)) {
    throw "RPT not found: $resolved"
}

Write-Host "Filter: $Pattern"
Write-Host "Press Ctrl+C to stop."
Write-Host "----"

# Print existing tail first, then follow.
Get-Content -Path $resolved -Tail $TailLines |
    Where-Object { $_ -match $Pattern } |
    ForEach-Object { Write-Host $_ }

Get-Content -Path $resolved -Wait -Tail 0 |
    Where-Object { $_ -match $Pattern } |
    ForEach-Object { Write-Host $_ }
