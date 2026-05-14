#!/usr/bin/env bash
# check_remoteexec_contract.sh
#
# Air/Tower RemoteExec static contract validation.
#
# Verifies:
#  1. Each Air/Tower client wrapper has a hasInterface guard.
#  2. Each Air/Tower client wrapper calls only a named (string-literal) server
#     function via remoteExec — no anonymous code blocks, no string-built targets.
#  3. Each Air/Tower server handler has an isServer guard.
#  4. Each Air/Tower server handler calls ARC_fnc_rpcValidateSender before mutation.
#  5. No Air/Tower file contains an anonymous remoteExec code block: remoteExec [{ ... }].
#  6. All 10 Air/Tower client→server RPC functions are in CfgRemoteExec.hpp allowlist.
#
# Usage: bash scripts/dev/check_remoteexec_contract.sh
# Exit:  0 = all checks passed, 1 = one or more failures.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

ok()   { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; pass=false; }

require_pattern() {
    local pattern="$1"
    local file="$2"
    local label="$3"
    if grep -Eq "$pattern" "$file"; then
        ok "$label"
    else
        fail "$label"
    fi
}

forbid_pattern() {
    local pattern="$1"
    local file="$2"
    local label="$3"
    if grep -Eq "$pattern" "$file"; then
        fail "$label"
    else
        ok "$label"
    fi
}

# ── 1 & 2: Client wrappers ─────────────────────────────────────────────────────

declare -A CLIENT_WRAPPERS
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientRequestHoldDepartures.sqf"]="ARC_fnc_airbaseRequestHoldDepartures"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientRequestReleaseDepartures.sqf"]="ARC_fnc_airbaseRequestReleaseDepartures"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientRequestPrioritizeFlight.sqf"]="ARC_fnc_airbaseRequestPrioritizeFlight"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientRequestCancelQueuedFlight.sqf"]="ARC_fnc_airbaseRequestCancelQueuedFlight"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientRequestSetLaneStaffing.sqf"]="ARC_fnc_airbaseRequestSetLaneStaffing"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientSubmitClearanceRequest.sqf"]="ARC_fnc_airbaseSubmitClearanceRequest"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientCancelClearanceRequest.sqf"]="ARC_fnc_airbaseCancelClearanceRequest"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientMarkClearanceEmergency.sqf"]="ARC_fnc_airbaseMarkClearanceEmergency"
CLIENT_WRAPPERS["functions/ambiance/fn_airbaseClientRequestClearanceDecision.sqf"]="ARC_fnc_airbaseRequestClearanceDecision"

echo "=== 1. Client wrapper hasInterface guards ==="
for file in "${!CLIENT_WRAPPERS[@]}"; do
    require_pattern '^\s*if\s*\(!hasInterface\)' "$file" \
        "hasInterface guard present: $file"
done

echo ""
echo "=== 2. Client wrapper named remoteExec targets (no anonymous blocks) ==="
for file in "${!CLIENT_WRAPPERS[@]}"; do
    target="${CLIENT_WRAPPERS[$file]}"
    require_pattern "remoteExec\s*\[\"${target}\"" "$file" \
        "named remoteExec to ${target}: $file"
    forbid_pattern 'remoteExec\s*\[\s*\{' "$file" \
        "no anonymous remoteExec block: $file"
done

# ── 3 & 4: Server handlers ─────────────────────────────────────────────────────

SERVER_HANDLERS=(
    functions/ambiance/fn_airbaseRequestHoldDepartures.sqf
    functions/ambiance/fn_airbaseRequestReleaseDepartures.sqf
    functions/ambiance/fn_airbaseRequestPrioritizeFlight.sqf
    functions/ambiance/fn_airbaseRequestCancelQueuedFlight.sqf
    functions/ambiance/fn_airbaseRequestSetLaneStaffing.sqf
    functions/ambiance/fn_airbaseSubmitClearanceRequest.sqf
    functions/ambiance/fn_airbaseCancelClearanceRequest.sqf
    functions/ambiance/fn_airbaseMarkClearanceEmergency.sqf
    functions/ambiance/fn_airbaseRequestClearanceDecision.sqf
    functions/ambiance/fn_airbaseAdminResetControlState.sqf
)

echo ""
echo "=== 3. Server handler isServer guards ==="
for file in "${SERVER_HANDLERS[@]}"; do
    require_pattern '^\s*if\s*\(!isServer\)' "$file" \
        "isServer guard present: $file"
done

echo ""
echo "=== 4. Server handler rpcValidateSender calls ==="
# Admin reset goes through tocRequestAirbaseResetControlState; check the main 9 RPC handlers only.
RPC_SERVER_HANDLERS=(
    functions/ambiance/fn_airbaseRequestHoldDepartures.sqf
    functions/ambiance/fn_airbaseRequestReleaseDepartures.sqf
    functions/ambiance/fn_airbaseRequestPrioritizeFlight.sqf
    functions/ambiance/fn_airbaseRequestCancelQueuedFlight.sqf
    functions/ambiance/fn_airbaseRequestSetLaneStaffing.sqf
    functions/ambiance/fn_airbaseSubmitClearanceRequest.sqf
    functions/ambiance/fn_airbaseCancelClearanceRequest.sqf
    functions/ambiance/fn_airbaseMarkClearanceEmergency.sqf
    functions/ambiance/fn_airbaseRequestClearanceDecision.sqf
)
for file in "${RPC_SERVER_HANDLERS[@]}"; do
    require_pattern 'ARC_fnc_rpcValidateSender' "$file" \
        "rpcValidateSender call present: $file"
done

# ── 5: No anonymous remoteExec blocks anywhere in Air/Tower files ──────────────

echo ""
echo "=== 5. No anonymous remoteExec blocks in any Air/Tower ambiance file ==="
while IFS= read -r -d '' file; do
    forbid_pattern 'remoteExec\s*\[\s*\{' "$file" \
        "no anonymous remoteExec block: $file"
done < <(find functions/ambiance -name 'fn_airbase*.sqf' -print0)

# ── 6: CfgRemoteExec allowlist completeness ────────────────────────────────────

ALLOWLIST_FILE="config/CfgRemoteExec.hpp"

EXPECTED_ALLOWLIST=(
    ARC_fnc_airbaseSubmitClearanceRequest
    ARC_fnc_airbaseRequestClearanceDecision
    ARC_fnc_airbaseRequestPrioritizeFlight
    ARC_fnc_airbaseCancelClearanceRequest
    ARC_fnc_airbaseRequestCancelQueuedFlight
    ARC_fnc_airbaseMarkClearanceEmergency
    ARC_fnc_airbaseRequestSetLaneStaffing
    ARC_fnc_airbaseRequestHoldDepartures
    ARC_fnc_airbaseRequestReleaseDepartures
    ARC_fnc_tocRequestAirbaseResetControlState
)

echo ""
echo "=== 6. CfgRemoteExec allowlist entries ==="
for fn in "${EXPECTED_ALLOWLIST[@]}"; do
    require_pattern "class\s+${fn}\s*\{" "$ALLOWLIST_FILE" \
        "CfgRemoteExec allowlist entry: $fn"
done

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
if [[ "$pass" != true ]]; then
    echo "Air/Tower RemoteExec contract checks FAILED."
    exit 1
fi

echo "Air/Tower RemoteExec contract checks PASSED."
