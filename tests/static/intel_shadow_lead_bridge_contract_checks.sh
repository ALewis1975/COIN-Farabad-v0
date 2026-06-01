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

check_absent() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -n "$pattern" "$file" >/dev/null; then
    echo "[FAIL] $label"
    pass=false
  else
    echo "[PASS] $label"
  fi
}

BRIDGE="functions/command/fn_intelShadowLeadBridge.sqf"

# C2 — SHADOW ISR → lead bridge reuses the existing TOC queue intake (no new handler).
check "remoteExec \[\"ARC_fnc_intelQueueSubmit\", 2\]" "$BRIDGE" "SHADOW ISR bridge submits via existing ARC_fnc_intelQueueSubmit RPC path"
check "\"LEAD_REQUEST\"" "$BRIDGE" "SHADOW ISR bridge submits a LEAD_REQUEST kind"
check "\[\"leadType\", _leadType\]" "$BRIDGE" "SHADOW ISR bridge payload includes leadType"
check "\[\"tag\", \"SHADOW_ISR\"\]" "$BRIDGE" "SHADOW ISR bridge tags the lead request SHADOW_ISR"
check "\[\"source\", \"SHADOW_ISR\"\]" "$BRIDGE" "SHADOW ISR bridge stamps source meta SHADOW_ISR"
check "ARC_isrShadowLeadBridgeEnabled" "$BRIDGE" "SHADOW ISR bridge honours the feature flag"
check "ARC_fnc_rolesHasGroupIdToken" "$BRIDGE" "SHADOW ISR bridge gates on the SHADOW callsign token"

# Doctrine: leads route through the TOC queue — the bridge must NOT create tasks
# or call leadCreate / tocBacklogEnqueue directly from the client.
check_absent "call ARC_fnc_leadCreate" "$BRIDGE" "SHADOW ISR bridge does not create leads directly"
check_absent "call ARC_fnc_tocBacklogEnqueue" "$BRIDGE" "SHADOW ISR bridge does not enqueue the TOC backlog directly"
check_absent "ARC_fnc_rpcValidateSender" "$BRIDGE" "SHADOW ISR bridge adds no new server validation handler"

# Wiring: flag seeded server-side and action registered.
check "ARC_isrShadowLeadBridgeEnabled" "initServer.sqf" "ARC_isrShadowLeadBridgeEnabled seeded in initServer"
check "ARC_fnc_intelShadowLeadBridge" "functions/core/fn_tocInitPlayer.sqf" "SHADOW ISR bridge wired as a player addAction"
check "class intelShadowLeadBridge" "config/CfgFunctions.hpp" "intelShadowLeadBridge registered in CfgFunctions"

if [[ "$pass" != true ]]; then
  exit 1
fi
