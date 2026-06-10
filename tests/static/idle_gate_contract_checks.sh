#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -n "$pattern" "$file" >/dev/null; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

HELPER="functions/core/fn_idleGateActive.sqf"

# Helper contract: server-only, kill-switch, HC exclusion, per-frame cache, transition logging.
check "if (!isServer) exitWith { false };" "$HELPER" "idle gate helper is server-only"
check "ARC_idleGateEnabled" "$HELPER" "idle gate helper honours ARC_idleGateEnabled kill switch"
check "HeadlessClient_F" "$HELPER" "idle gate helper excludes headless clients from interfaced-player count"
check "ARC_idleGateGraceS" "$HELPER" "idle gate helper applies ARC_idleGateGraceS grace window"
check "diag_frameNo" "$HELPER" "idle gate helper caches its result per engine frame"
check "\[ARC\]\[IDLE\]\[INFO\]" "$HELPER" "idle gate helper logs pause/resume transitions"

# Registration + defaults.
check "class idleGateActive {};" "config/CfgFunctions.hpp" "idleGateActive registered in CfgFunctions"
check "ARC_idleGateEnabled" "initServer.sqf" "ARC_idleGateEnabled seeded in initServer"
check "ARC_idleGateGraceS" "initServer.sqf" "ARC_idleGateGraceS seeded in initServer"

# Gated ticks: lead generation, medical decay, ambient spawn ticks.
check "ARC_fnc_idleGateActive" "functions/civsub/fn_civsubSchedulerTick.sqf" "lead generation scheduler is idle-gated"
check "ARC_fnc_idleGateActive" "functions/logistics/fn_supplyApplyAmbientDrain.sqf" "ambient sustainment (medical) decay is idle-gated"
check "ARC_fnc_idleGateActive" "functions/medical/fn_medicalTick.sqf" "medical recovery tick is idle-gated"
check "ARC_fnc_idleGateActive" "functions/civsub/fn_civsubCivSamplerTick.sqf" "civ sampler spawn tick is idle-gated"
check "ARC_fnc_idleGateActive" "functions/civsub/fn_civsubTrafficTick.sqf" "civ traffic spawn tick is idle-gated"
check "ARC_fnc_idleGateActive" "functions/civsub/fn_civsubLocNpcTick.sqf" "location-NPC spawn tick is idle-gated"
check "ARC_fnc_idleGateActive" "functions/ambiance/fn_airbaseGroundTrafficTick.sqf" "airbase ground-traffic spawn tick is idle-gated"
check "ARC_fnc_idleGateActive" "functions/sitepop/fn_sitePopTick.sqf" "sitepop proximity/spawn loop is idle-gated"

# Drain clock contract: idle exit must advance sustainLastAt so no retroactive drain.
check 'exitWith {$' "functions/logistics/fn_supplyApplyAmbientDrain.sqf" "ambient drain idle exit is multi-line (clock reset block)"
check '\["sustainLastAt", serverTime\] call ARC_fnc_stateSet' "functions/logistics/fn_supplyApplyAmbientDrain.sqf" "ambient drain idle exit advances sustainLastAt"

if $pass; then
  echo "All idle-gate contract checks passed."
else
  echo "Idle-gate contract checks FAILED."
  exit 1
fi
