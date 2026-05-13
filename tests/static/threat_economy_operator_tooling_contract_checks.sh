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

check 'class threatEconomySnapshotBuild {}' "config/CfgFunctions.hpp" "CfgFunctions registers threatEconomySnapshotBuild"
check 'threat_v0_economy_deny_reason_enum' "functions/threat/fn_threatEconomyInit.sqf" "Threat economy init seeds deny taxonomy enum"
check 'threat_v0_economy_last_decision' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler writes last economy decision"
check 'threat_v0_economy_deny_counts' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler tracks economy deny counts"
check 'threat_economy_obs_v1' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot builder publishes threat_economy_obs_v1 schema"
check 'denyReasonTaxonomy' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot includes deny reason taxonomy"
check 'districtRows' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot includes per-district rows"
check '\["threatEconomy", _threatEconomyPub\]' "functions/core/fn_publicBroadcastState.sqf" "Public state includes threatEconomy snapshot"
check 'ARC_pub_threatEconomySnapshot' "functions/core/fn_publicBroadcastState.sqf" "Threat economy snapshot is replicated explicitly"
check '\["economy", _threatEconomySnapshot\]' "functions/core/fn_consoleVmBuild.sqf" "Console VM threat section includes economy snapshot"
check 'Threat Economy Operator Tooling v1' "docs/planning/threat/Threat_Economy_Operator_Tooling_Implementation_v1.md" "Epic 7 implementation doc added"
check 'Completion rubric' "docs/planning/threat/Threat_Economy_Operator_Tooling_Implementation_v1.md" "Epic 7 doc includes completion rubric"

if [[ "$pass" != true ]]; then
  exit 1
fi
