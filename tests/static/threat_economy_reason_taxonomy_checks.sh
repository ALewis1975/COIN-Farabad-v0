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

check 'ARC_fnc_threatEconomyReasonMeta' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Reason taxonomy helper exists"
check 'ALLOW_GOVERNOR' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes allow governor reason"
check 'ALLOW_SCHEDULED' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes scheduled reason"
check 'SCHEDULE_FAILED' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes schedule-failed warning reason"
check 'THREAT_DISABLED' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes threat disabled denial"
check 'GLOBAL_COOLDOWN' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes global cooldown denial"
check 'DISTRICT_COOLDOWN' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes district cooldown denial"
check 'BUDGET_EXHAUSTED' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes budget denial"
check 'ESCALATION_TIER' "functions/threat/fn_threatEconomyReasonMeta.sqf" "Taxonomy includes escalation denial"
check 'reason_meta' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records reason metadata in decisions"
check 'reason_code' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records stable reason code in decisions"
check 'threat_v0_economy_reason_taxonomy' "functions/threat/fn_threatEconomyInit.sqf" "Economy init seeds reason taxonomy state"
check 'reasonTaxonomy' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes reason taxonomy"
check 'lastWarningDecision' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes warning decision"
check 'denyReasonCounts' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot preserves denial counts"

if [[ "$pass" != true ]]; then
  exit 1
fi
