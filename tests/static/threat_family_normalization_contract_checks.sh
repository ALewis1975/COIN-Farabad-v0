#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -q "$pattern" "$file"; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

check 'threat_v0_family_enum' "functions/threat/fn_threatInit.sqf" "Threat init seeds family enum"
check 'threat_v0_deny_reason_enum' "functions/threat/fn_threatInit.sqf" "Threat init seeds deny-reason enum"
check 'class threatInferFamily {}' "config/CfgFunctions.hpp" "CfgFunctions registers threatInferFamily helper"
check 'ARC_fnc_threatInferFamily' "functions/threat/fn_threatCreateFromTask.sqf" "Threat create uses shared family inference helper"
check '\["family", _familyU\]' "functions/threat/fn_threatCreateFromTask.sqf" "Threat create writes normalized family field"
check 'THREAT_STATE_CHANGE_DENIED' "functions/threat/fn_threatUpdateState.sqf" "Threat update emits denied transition event"
check '\["deny_reason", _denyReason\]' "functions/threat/fn_threatUpdateState.sqf" "Threat update payload carries deny reason"
check '\["families", _familyFilters\]' "functions/threat/fn_threatUiSnapshotBuild.sqf" "Threat UI snapshot exposes family filters"
check 'Threat Family Normalization v1' "docs/planning/threat/Threat_Family_Normalization_Implementation_v1.md" "Epic 4 implementation doc added"
check 'Family matrix' "docs/planning/threat/Threat_Family_Normalization_Implementation_v1.md" "Epic 4 doc includes family matrix"

if [[ "$pass" != true ]]; then
  exit 1
fi
