#!/usr/bin/env bash
set -euo pipefail

# Console VM section contract checks.
#
# Guards against the stub-section regressions found in the 2026-06-11 review:
#   - personnel section read a key no publisher writes (ARC_pub_s1Registry
#     instead of ARC_pub_s1_registry)
#   - handoff section read ARC_pub_handoffState, which has no publisher
#   - stub sections stamped freshness with build-time _now, making staleness
#     detection meaningless
# Also asserts the painter-migration contract (VM-primary with direct-read
# fallback) for the tabs migrated in PR 5 (INTEL, HQ, BOARDS, HANDOFF).

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

check_absent() {
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

VM="functions/core/fn_consoleVmBuild.sqf"

# --- personnel section: real publisher key + real freshness -----------------
check 'ARC_pub_s1_registry"' "$VM" "personnel section reads ARC_pub_s1_registry (real publisher key)"
check 'ARC_pub_s1_registryUpdatedAt' "$VM" "personnel freshness sourced from ARC_pub_s1_registryUpdatedAt"
check_absent 'ARC_pub_s1Registry"' "$VM" "stale ARC_pub_s1Registry key removed"

# --- handoff section: no dead publisher; sourced from orders ----------------
check_absent 'ARC_pub_handoffState' "$VM" "dead ARC_pub_handoffState read removed"
check '\["orders",[[:space:]]*_orders\]' "$VM" "handoff section sourced from published orders"

# --- intelFeed section: real freshness ---------------------------------------
check 'ARC_pub_intelUpdatedAt' "$VM" "intelFeed freshness sourced from ARC_pub_intelUpdatedAt"

# --- stateSummary: real freshness + mission score for HQ ----------------------
check 'ARC_pub_stateUpdatedAt' "$VM" "stateSummary freshness sourced from ARC_pub_stateUpdatedAt"
check '\["mission_score",[[:space:]]*_missionScore\]' "$VM" "stateSummary carries mission_score for HQ"
check '\["mission_score_at",[[:space:]]*_missionScoreAt\]' "$VM" "stateSummary carries mission_score_at for HQ"

# --- painter migrations: VM-primary with direct-read fallback ----------------
INTEL="functions/ui/fn_uiConsoleIntelPaint.sqf"
check '\["intelFeed",[[:space:]]*"log"' "$INTEL" "INTEL reads intel log from VM intelFeed section"
check 'missionNamespace getVariable \["ARC_pub_intelLog"' "$INTEL" "INTEL retains direct intel-log fallback"

HQ="functions/ui/fn_uiConsoleHQPaint.sqf"
check '\["stateSummary",[[:space:]]*"mission_score"' "$HQ" "HQ reads mission score from VM stateSummary section"
check 'missionNamespace getVariable \["ARC_pub_missionScore"' "$HQ" "HQ retains direct mission-score fallback"

BOARDS="functions/ui/fn_uiConsoleBoardsPaint.sqf"
check 'ARC_fnc_consoleVmAdapterV1' "$BOARDS" "BOARDS uses Console VM adapter"
check '\["incident",[[:space:]]*"task_id"' "$BOARDS" "BOARDS reads incident from VM"
check '\["ops",[[:space:]]*"queue_pending"' "$BOARDS" "BOARDS reads queue from VM"
check '\["ops",[[:space:]]*"orders"' "$BOARDS" "BOARDS reads orders from VM"
check 'missionNamespace getVariable \["ARC_pub_queuePending"' "$BOARDS" "BOARDS retains queue fallback"
check 'missionNamespace getVariable \["ARC_pub_opsLog"' "$BOARDS" "BOARDS keeps full ops-log direct read (SITREP may be older than VM log_tail)"

HANDOFF="functions/ui/fn_uiConsoleHandoffPaint.sqf"
check '\["handoff",[[:space:]]*"orders"' "$HANDOFF" "HANDOFF reads orders from VM handoff section"
check 'missionNamespace getVariable \["ARC_pub_orders"' "$HANDOFF" "HANDOFF retains direct orders fallback"

# --- descoped tabs stay on rev-checked direct reads (documented exception) ---
check 'ARC_pub_airbaseUiSnapshot' "functions/ui/fn_uiConsoleAirPaint.sqf" "AIR keeps rev-checked direct snapshot read (descoped per plan §12.3)"
check 'ARC_pub_s1_registry' "functions/ui/fn_uiConsoleS1Paint.sqf" "S1 keeps rev-checked direct registry read (descoped per plan §12.3)"

# --- dead feature flags removed ----------------------------------------------
check_absent 'ARC_console_ops_v2' "initServer.sqf" "dead ARC_console_ops_v2 seeding removed from initServer"
check_absent 'ARC_console_dashboard_v2' "initServer.sqf" "dead ARC_console_dashboard_v2 seeding removed from initServer"
check_absent 'ARC_console_command_v2' "functions/ui/fn_uiConsoleCommandPaint.sqf" "stale command_v2 comment removed from CommandPaint"

if [[ "$pass" != true ]]; then
  exit 1
fi
