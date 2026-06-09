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

check 'unit_statuses' "functions/core/fn_consoleVmBuild.sqf" "Console VM exposes unit statuses"
check 'toc_backlog' "functions/core/fn_consoleVmBuild.sqf" "Console VM exposes TOC backlog"
check 'base_services' "functions/core/fn_consoleVmBuild.sqf" "Console VM exposes base services in stateSummary"

check 'ARC_fnc_consoleVmAdapterV1' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard uses Console VM adapter"
check '\["ops",[[:space:]]*"unit_statuses"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard reads unit statuses from VM"
check '\["ops",[[:space:]]*"toc_backlog"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard reads TOC backlog from VM"
check '\["airbase",[[:space:]]*"snapshot"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard reads airbase snapshot from VM"
check '\["stateSummary",[[:space:]]*"base_services"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard reads base services from VM"

check 'fallback-only' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard documents direct reads as fallback only"
check 'missionNamespace getVariable \["ARC_pub_unitStatuses"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard retains unit-status fallback"
check 'missionNamespace getVariable \["ARC_pub_airbaseUiSnapshot"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard retains airbase fallback"
check 'missionNamespace getVariable \["ARC_pub_baseServices"' "functions/ui/fn_uiConsoleDashboardPaint.sqf" "Dashboard retains base-services fallback"

if [[ "$pass" != true ]]; then
  exit 1
fi
