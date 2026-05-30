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

check 'ARC_threatVirtualMinSpawnDistM' "initServer.sqf" "Minimum spawn standoff constant is published to clients"
check 'ARC_threatVirtualMinSpawnDistM' "functions/threat/fn_threatVirtualPoolTick.sqf" "Pool tick reads the minimum spawn standoff constant"
check '_minSpawnDistM[[:space:]]*=[[:space:]]*\(_minSpawnDistM[[:space:]]*max[[:space:]]*0\)' "functions/threat/fn_threatVirtualPoolTick.sqf" "Standoff constant is clamped to a non-negative value"

# Shared standoff predicate (single source of truth for the spawn rule).
check 'class threatSpawnPosClear' "config/CfgFunctions.hpp" "Shared standoff predicate is registered in CfgFunctions"
check 'distance2D _pos' "functions/threat/fn_threatSpawnPosClear.sqf" "Predicate enforces a player standoff distance"
check 'ARC_fnc_threatIsProtectedSpawnPos' "functions/threat/fn_threatSpawnPosClear.sqf" "Predicate enforces the protected-zone guard"

# Pool tick uses the shared predicate and a multi-bearing search before deferring.
check 'ARC_fnc_threatSpawnPosClear' "functions/threat/fn_threatVirtualPoolTick.sqf" "Pool tick relocates spawns via the shared predicate"
check '_offsets[[:space:]]*=[[:space:]]*\[0, 30, -30' "functions/threat/fn_threatVirtualPoolTick.sqf" "Pool tick sweeps multiple bearings before deferring"
check 'spawn deferred' "functions/threat/fn_threatVirtualPoolTick.sqf" "Spawn is deferred only when no clear bearing can be found"
check 'spawn pushed to' "functions/threat/fn_threatVirtualPoolTick.sqf" "Spawn position is pushed outward to the standoff distance"

# Ops patrol contacts share the same standoff rule.
check 'ARC_fnc_threatSpawnPosClear' "functions/ops/fn_opsPatrolOnActivate.sqf" "Ops patrol contacts use the shared standoff predicate"

check 'ARC_threatVirtualMinSpawnDistM' "docs/architecture/Configuration_Ownership_Ledger.md" "Ledger documents the standoff constant"

if [[ "$pass" != true ]]; then
  exit 1
fi
