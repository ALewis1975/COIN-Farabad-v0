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

check 'class threatUiSnapshotBuild {}' "config/CfgFunctions.hpp" "CfgFunctions registers threatUiSnapshotBuild"
check 'class threatUiDiaryRefresh {}' "config/CfgFunctions.hpp" "CfgFunctions registers threatUiDiaryRefresh"
check '\["threat", _threatPub\]' "functions/core/fn_publicBroadcastState.sqf" "Public state includes threat snapshot block"
check 'ARC_pub_threatUiSnapshot' "functions/core/fn_publicBroadcastState.sqf" "Threat UI snapshot is replicated explicitly"
check '\["threat",       _threatSection\]' "functions/core/fn_consoleVmBuild.sqf" "Console VM publishes threat section"
check 'ARC_fnc_threatUiDiaryRefresh' "functions/core/fn_clientSnapshotRefresh.sqf" "Client snapshot refresh calls threat diary refresh"
check 'Read-only operator surface' "functions/core/fn_threatUiDiaryRefresh.sqf" "Threat diary refresh renders read-only operator surface"
check '\["schema", "threat_ui_v1"\]' "functions/threat/fn_threatUiSnapshotBuild.sqf" "Threat UI snapshot builder publishes threat_ui_v1 schema"

if [[ "$pass" != true ]]; then
  exit 1
fi
