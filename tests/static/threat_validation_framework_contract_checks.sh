#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -Eq "$pattern" "$file"; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

DOC="docs/planning/threat/Threat_Validation_Evidence_Framework_v1.md"

check '^# Threat Validation Evidence Framework v1' "$DOC" "Epic 6 framework doc exists"
check '^## Validation matrix scope' "$DOC" "Framework includes validation matrix scope section"
check '^## Evidence status semantics' "$DOC" "Framework documents evidence semantics section"
check '`PASS`' "$DOC" "Framework documents PASS semantics"
check '`FAIL`' "$DOC" "Framework documents FAIL semantics"
check '`BLOCKED`' "$DOC" "Framework documents BLOCKED semantics"
check 'Owner: <team/person>' "$DOC" "Framework requires blocked-row owner field"
check 'Date: YYYY-MM-DD' "$DOC" "Framework requires blocked-row date field"
check 'Requires:' "$DOC" "Framework requires blocked-row environment/dependency field"
check 'Next step:' "$DOC" "Framework requires blocked-row follow-up field"
check 'Local MP smoke procedure' "$DOC" "Framework includes Local MP procedure"
check 'Dedicated server procedure' "$DOC" "Framework includes dedicated procedure"
check 'JIP late-join procedure' "$DOC" "Framework includes JIP procedure"
check 'Restart/save-load procedure' "$DOC" "Framework includes restart procedure"
check 'Reconnect/respawn procedure' "$DOC" "Framework includes reconnect procedure"
check 'In-flight lifecycle edge procedure' "$DOC" "Framework includes in-flight lifecycle edge procedure"
check 'tests/TEST-LOG.md' "$DOC" "Framework documents TEST-LOG evidence updates"
check 'Final validation closure MUST NOT be claimed unless every required evidence row is PASS with linked artifacts\.' "$DOC" "Framework forbids closure claim without evidence"
check 'No new runtime threat features are introduced in this PR\.' "$DOC" "Framework explicitly scopes out runtime threat features"

if [[ "$pass" != true ]]; then
  exit 1
fi
