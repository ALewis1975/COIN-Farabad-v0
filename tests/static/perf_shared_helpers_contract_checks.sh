#!/usr/bin/env bash
set -euo pipefail

# Contract checks for the shared performance helpers:
#   - ARC_fnc_playerSnapshot : per-frame-cached [unit, posATL] snapshot of allPlayers
#   - ARC_fnc_cfgClassExists : memoized CfgVehicles class-existence lookup
# These lock in registration, helper internals, and the refactored call sites so a
# regression that silently reverts the optimization (or breaks behaviour) fails CI.

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

absent() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -Eq "$pattern" "$file"; then
    echo "[FAIL] $label"
    pass=false
  else
    echo "[PASS] $label"
  fi
}

# --- Registration -----------------------------------------------------------
check 'class playerSnapshot' "config/CfgFunctions.hpp" "CfgFunctions registers playerSnapshot"
check 'class cfgClassExists' "config/CfgFunctions.hpp" "CfgFunctions registers cfgClassExists"

# --- Player-snapshot helper internals --------------------------------------
check 'diag_frameNo' "functions/core/fn_playerSnapshot.sqf" "Snapshot is keyed by the engine frame"
check 'ARC_playerSnapshotFrame' "functions/core/fn_playerSnapshot.sqf" "Snapshot caches the frame marker"
check 'ARC_playerSnapshotData' "functions/core/fn_playerSnapshot.sqf" "Snapshot caches the data payload"
check 'allPlayers apply' "functions/core/fn_playerSnapshot.sqf" "Snapshot is built once from allPlayers"

# --- Config-class cache internals ------------------------------------------
check 'ARC_cfgClassExistsCache' "functions/core/fn_cfgClassExists.sqf" "Class-existence results are memoized"
check 'isClass \(configFile >> _root' "functions/core/fn_cfgClassExists.sqf" "Cache miss falls back to a real isClass lookup"

# --- Player-snapshot call sites --------------------------------------------
check 'call ARC_fnc_playerSnapshot' "functions/civsub/fn_civsubIsDistrictActive.sqf" "District-active scan uses the shared snapshot"
check 'call ARC_fnc_playerSnapshot' "functions/ambiance/fn_airbaseGroundTrafficTick.sqf" "Ground-traffic presence check uses the shared snapshot"
check 'call ARC_fnc_playerSnapshot' "functions/core/fn_cleanupTick.sqf" "Cleanup proximity check uses the shared snapshot"
check 'call ARC_fnc_playerSnapshot' "functions/civsub/fn_civsubLocNpcTick.sqf" "Loc-NPC bubble check uses the shared snapshot"

# Behaviour anchors that must survive the refactor.
check '_min <= \(_r \+ 200\)' "functions/civsub/fn_civsubIsDistrictActive.sqf" "District-active rule (radius + 200) is preserved"
check 'alive \(_x select 0\)' "functions/core/fn_cleanupTick.sqf" "Cleanup still filters to alive players"
check 'alive \(_x select 0\)' "functions/civsub/fn_civsubLocNpcTick.sqf" "Loc-NPC still filters to alive players"

# --- Config-class cache call sites -----------------------------------------
check 'call ARC_fnc_cfgClassExists' "functions/threat/fn_threatVirtualPoolTick.sqf" "Pool tick validates unit classes via the cache"
check 'call ARC_fnc_cfgClassExists' "functions/threat/fn_threatVirtualPoolInit.sqf" "Pool init validates unit classes via the cache"
absent 'isClass \(configFile >> "CfgVehicles" >> _x\)' "functions/threat/fn_threatVirtualPoolTick.sqf" "Pool tick no longer re-runs raw per-class isClass each tick"
absent 'isClass \(configFile >> "CfgVehicles" >> _x\)' "functions/threat/fn_threatVirtualPoolInit.sqf" "Pool init no longer re-runs raw per-class isClass"

if [[ "$pass" != true ]]; then
  exit 1
fi
