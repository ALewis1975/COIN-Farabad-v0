#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/tools/dev_deploy/deploy.ps1"
VERIFY="$ROOT/tools/dev_deploy/verify.ps1"
SYNC="$ROOT/tools/sync_mission_to_arma_profile.ps1"
README="$ROOT/tools/dev_deploy/README.md"

fail(){ echo "FAIL: $*" >&2; exit 1; }
need(){ [[ -f "$1" ]] || fail "missing ${1#$ROOT/}"; }
has(){ grep -Fq -- "$2" "$1" || fail "${1#$ROOT/} missing: $2"; }
not_has(){ ! grep -Fq -- "$2" "$1" || fail "${1#$ROOT/} contains prohibited text: $2"; }

for f in "$DEPLOY" "$VERIFY" "$SYNC" "$README"; do need "$f"; done
has "$DEPLOY" 'git status --porcelain'
has "$DEPLOY" 'git rev-parse HEAD'
has "$DEPLOY" 'ARC_DeploymentManifest.json'
has "$DEPLOY" 'deployedInitServerSha256'
has "$DEPLOY" 'Deployment changed the repository working tree'
not_has "$DEPLOY" 'Set-Content -NoNewline -Path $initServer'
has "$SYNC" '[switch]$VerifyOnly'
has "$SYNC" 'Get-ChildItem -LiteralPath $Root -Recurse -File'
has "$SYNC" 'unexpected destination-only file'
has "$SYNC" 'expected deployment build stamp missing'
has "$VERIFY" 'Repository HEAD does not match deployed candidate'
has "$VERIFY" 'Repository is dirty; deployment verification is not trustworthy'
has "$README" 'OneDrive warning'
has "$README" 'The repository file is not modified.'
has "$README" 'Ten-minute smoke check'
python3 - "$DEPLOY" "$SYNC" "$VERIFY" <<'PY'
from pathlib import Path
import sys
for raw in sys.argv[1:]:
    text=Path(raw).read_text(encoding="utf-8")
    assert text.count("{")==text.count("}"), f"unbalanced braces: {raw}"
    assert text.count("(")==text.count(")"), f"unbalanced parentheses: {raw}"
PY
echo "PASS: deployment provenance contract checks passed."
