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

check 'class[[:space:]]*threatVirtualPoolSnapshotBuild' "config/CfgFunctions.hpp" "CfgFunctions registers threatVirtualPoolSnapshotBuild"
check 'threat_virtual_opfor_obs_v1' "functions/threat/fn_threatVirtualPoolSnapshotBuild.sqf" "Virtual OpFor snapshot builder publishes threat_virtual_opfor_obs_v1 schema"
check 'active_index_orphan_count' "functions/threat/fn_threatVirtualPoolSnapshotBuild.sqf" "Virtual OpFor snapshot includes active index orphan diagnostics"
check 'materialized_group_rows_truncated' "functions/threat/fn_threatVirtualPoolSnapshotBuild.sqf" "Virtual OpFor snapshot exposes row truncation visibility"
check 'protectedZones' "functions/threat/fn_threatVirtualPoolSnapshotBuild.sqf" "Virtual OpFor snapshot includes protected-zone observability block"
check 'locality' "functions/threat/fn_threatVirtualPoolSnapshotBuild.sqf" "Virtual OpFor snapshot includes locality interpretation block"
check '\["threatVirtualPool", _threatVirtualPoolPub\]' "functions/core/fn_publicBroadcastState.sqf" "Public state includes threatVirtualPool snapshot"
check 'ARC_pub_threatVirtualPoolSnapshot' "functions/core/fn_publicBroadcastState.sqf" "Virtual OpFor snapshot is replicated explicitly"
check '\["virtualPool", _threatVirtualPoolSnapshot\]' "functions/core/fn_consoleVmBuild.sqf" "Console VM threat section includes virtualPool snapshot"
check 'Threat Virtual OpFor Observability Implementation v1' "docs/planning/threat/Threat_Virtual_OpFor_Observability_Implementation_v1.md" "Epic 8 implementation doc added"
check 'Evidence plan and known validation gaps' "docs/planning/threat/Threat_Virtual_OpFor_Observability_Implementation_v1.md" "Epic 8 doc includes dedicated/JIP/restart evidence-gap framing"

if [[ "$pass" != true ]]; then
  exit 1
fi
