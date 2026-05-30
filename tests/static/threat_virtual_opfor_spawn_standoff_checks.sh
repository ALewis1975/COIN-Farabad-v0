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
check '_nearestPlayerD[[:space:]]*<[[:space:]]*_minSpawnDistM' "functions/threat/fn_threatVirtualPoolTick.sqf" "Spawn gate compares nearest player distance against the standoff bubble"
check 'spawn deferred' "functions/threat/fn_threatVirtualPoolTick.sqf" "Spawn is deferred when no safe standoff position can be found"
check 'spawn pushed to' "functions/threat/fn_threatVirtualPoolTick.sqf" "Spawn position is pushed outward to the standoff distance"
check 'ARC_threatVirtualMinSpawnDistM' "docs/architecture/Configuration_Ownership_Ledger.md" "Ledger documents the standoff constant"

if [[ "$pass" != true ]]; then
  exit 1
fi
