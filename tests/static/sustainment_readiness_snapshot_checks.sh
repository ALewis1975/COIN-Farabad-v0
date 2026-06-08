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

check 'ARC_fnc_sustainmentReadinessSnapshot' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Sustainment readiness helper exists"
check 'if \(!isServer\) exitWith \{\[\]\}' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot builder is server-guarded"
check 'sustainment_readiness_v1' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot declares sustainment schema"
check 'lace' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot emits LACE block"
check 'mett_tc_inputs' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot emits METT-TC inputs"
check 'follow_on_bias' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot emits follow-on bias"
check 'activeIncidentSitrepSupplyAnnex' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot reads active SITREP supply annex"
check 'activeIncidentSitrepReadinessDelta' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot reads active readiness delta"
check 'activeIncidentMettTcAssessment' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot reads active METT-TC assessment"
check 'ARC_fnc_supplyGetStockSnapshot' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot consumes supply stock"
check 'ARC_fnc_medicalSnapshot' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot consumes medical snapshot"
check 'casevac_required' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot includes CASEVAC signal"
check 'resupply_recommended' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot includes resupply signal"
check 'refit_recommended' "functions/logistics/fn_sustainmentReadinessSnapshot.sqf" "Snapshot includes refit signal"
check 'sustainmentReadiness' "functions/logistics/fn_supplyBuildPublicSnapshot.sqf" "Supply public snapshot includes sustainment readiness"
check 'fn_sustainmentReadinessSnapshot.sqf' "functions/logistics/fn_supplyBuildPublicSnapshot.sqf" "Supply snapshot lazy-loads sustainment helper"

if [[ "$pass" != true ]]; then
  exit 1
fi
