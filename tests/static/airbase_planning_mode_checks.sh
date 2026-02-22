#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

require_pattern() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if rg -n "$pattern" "$file" >/dev/null; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

require_pattern 'missionNamespace setVariable \["airbase_v1_runtime_enabled", false, true\];' initServer.sqf "AIRBASE runtime gate defaults to planning-only (false)"
require_pattern 'class airbasePostInit \{ postInit = 1; \};' config/CfgFunctions.hpp "AIRBASE postInit registration exists and is subject to runtime gate"

entry_files=(
  functions/ambiance/fn_airbasePostInit.sqf
  functions/ambiance/fn_airbaseInit.sqf
  functions/ambiance/fn_airbaseTick.sqf
  functions/ambiance/fn_airbaseSpawnArrival.sqf
  functions/ambiance/fn_airbasePlaneDepart.sqf
  functions/ambiance/fn_airbaseAttackTowDepart.sqf
  functions/ambiance/fn_airbaseSecurityInit.sqf
  functions/ambiance/fn_airbaseSecurityPatrol.sqf
  functions/ambiance/fn_airbaseSubmitClearanceRequest.sqf
  functions/ambiance/fn_airbaseCancelClearanceRequest.sqf
  functions/ambiance/fn_airbaseMarkClearanceEmergency.sqf
  functions/ambiance/fn_airbaseRequestClearanceDecision.sqf
  functions/ambiance/fn_airbaseRequestHoldDepartures.sqf
  functions/ambiance/fn_airbaseRequestReleaseDepartures.sqf
  functions/ambiance/fn_airbaseRequestPrioritizeFlight.sqf
  functions/ambiance/fn_airbaseRequestCancelQueuedFlight.sqf
  functions/ambiance/fn_airbaseRequestSetLaneStaffing.sqf
  functions/ambiance/fn_airbaseAdminResetControlState.sqf
)

for file in "${entry_files[@]}"; do
  require_pattern 'ARC_fnc_airbaseRuntimeEnabled' "$file" "Runtime entrypoint gate present in $file"
done

if [[ "$pass" != true ]]; then
  echo "AIRBASE planning-mode static checks failed."
  exit 1
fi

echo "AIRBASE planning-mode static checks passed."
