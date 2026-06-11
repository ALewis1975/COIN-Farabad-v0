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

RECORD="functions/core/fn_securityDenyRecord.sqf"
VALIDATOR="functions/core/fn_rpcValidateSender.sqf"
WATCHER="functions/ui/fn_uiNextIncidentDenyWatchClient.sqf"
HQPAINT="functions/ui/fn_uiConsoleHQPaint.sqf"
TOCNEXT="functions/core/fn_tocRequestNextIncident.sqf"

# --- Track 3.1: SECURITY_DENIED ring buffer (server-authoritative) ---
check 'if (!isServer) exitWith { false };' "$RECORD" "securityDenyRecord is server-only"
check 'ARC_pub_securityDenials' "$RECORD" "securityDenyRecord writes the replicated diagnostics buffer"
check 'setVariable \["ARC_pub_securityDenials", _log, true\]' "$RECORD" "securityDenyRecord publishes globally (server single-writer)"
check 'while { (count _log) > _max } do { _log deleteAt 0; };' "$RECORD" "securityDenyRecord bounds the buffer"
check 'class securityDenyRecord' "config/CfgFunctions.hpp" "securityDenyRecord registered in CfgFunctions"

# Validator records all three deny reasons.
check 'ARC_fnc_securityDenyRecord' "$VALIDATOR" "rpcValidateSender wired to securityDenyRecord"
check '"MISSING_REMOTE_CONTEXT", -1\] call ARC_fnc_securityDenyRecord' "$VALIDATOR" "MISSING_REMOTE_CONTEXT strict denial recorded"
check '"NULL_OBJECT", _actualOwner\] call ARC_fnc_securityDenyRecord' "$VALIDATOR" "NULL_OBJECT denial recorded"
check '"OWNER_MISMATCH", _actualOwner\] call ARC_fnc_securityDenyRecord' "$VALIDATOR" "OWNER_MISMATCH denial recorded"

# --- Track 3.2: passive client deny toast watcher ---
check 'if (!hasInterface) exitWith { false };' "$WATCHER" "deny watcher is client-only"
check 'missionName, missionStart' "$WATCHER" "deny watcher uses per-mission session token guard (not a boolean)"
check 'ARC_pub_nextIncidentLastDenied' "$WATCHER" "deny watcher consumes the replicated last-denied record"
check 'ARC_fnc_rolesCanApproveQueue' "$WATCHER" "deny watcher role-gated to TOC queue approvers"
check 'ARC_fnc_clientToast' "$WATCHER" "deny watcher surfaces denials as client toasts"
check_absent 'setVariable \["ARC_pub_' "$WATCHER" "deny watcher never writes replicated mission state from a client"
check 'class uiNextIncidentDenyWatchClient' "config/CfgFunctions.hpp" "deny watcher registered in CfgFunctions"
check 'ARC_fnc_uiNextIncidentDenyWatchClient' "initPlayerLocal.sqf" "deny watcher started from initPlayerLocal"

# Server publishes the requester owner so the watcher can de-duplicate toasts.
check '_detail, _ownerId\],' "$TOCNEXT" "nextIncidentLastDenied includes the requester owner id"

# --- Track 3.3: HQ console Server Health (Live) diagnostics pane ---
check 'ADMIN_DIAG_SERVER' "$HQPAINT" "HQ console exposes the Server Health (Live) diagnostics row"
check '"Server Health (Live)", "ADMIN_DIAG_SERVER"' "$HQPAINT" "Server Health row added to the DIAGNOSTICS section"
check 'ARC_serverReady' "$HQPAINT" "Server Health pane reads ARC_serverReady"
check 'ARC_pub_securityDenials' "$HQPAINT" "Server Health pane renders recent security denials"
check 'ARC_pub_stateUpdatedAt' "$HQPAINT" "Server Health pane reports state snapshot age"
check 'ARC_pub_airbaseUiSnapshotUpdatedAt' "$HQPAINT" "Server Health pane reports airbase snapshot age"
check 'ARC_pub_threatUiSnapshotUpdatedAt' "$HQPAINT" "Server Health pane reports threat snapshot age"
check 'ARC_fnc_uiConsoleFormatAgo' "$HQPAINT" "Server Health pane uses the shared age formatter"

if $pass; then
  echo "All dedicated observability contract checks passed."
else
  echo "Dedicated observability contract checks FAILED."
  exit 1
fi
