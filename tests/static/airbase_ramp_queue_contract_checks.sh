#!/usr/bin/env bash
# tests/static/airbase_ramp_queue_contract_checks.sh
#
# Static contract checks for the ATC Ramp Queue feature (Mode B):
#   - parkedAssets key in public snapshot
#   - New server RPC security patterns (remoteExecutedOwner, rpcValidateSender, airbaseTowerAuthorize)
#   - METT-TC priority config in fn_airbaseTick.sqf
#   - CfgFunctions + CfgRemoteExec registrations
#   - RAMP submode in UIConsoleAirPaint, ActionAirPrimary, ActionAirSecondary

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pass=true

require_pattern() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if ! grep -qE "$pattern" "$REPO_ROOT/$file"; then
        echo "FAIL: $desc"
        echo "      File: $file"
        echo "      Pattern: $pattern"
        pass=false
    else
        echo "PASS: $desc"
    fi
}

require_absent() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if grep -qE "$pattern" "$REPO_ROOT/$file"; then
        echo "FAIL: $desc (pattern must be ABSENT)"
        echo "      File: $file"
        echo "      Pattern: $pattern"
        pass=false
    else
        echo "PASS: $desc"
    fi
}

echo "=== Airbase Ramp Queue Contract Checks ==="
echo ""

# -----------------------------------------------------------------------
# 1. Server RPC security chain
# -----------------------------------------------------------------------
echo "-- Section 1: Server RPC security chain --"

RPC="functions/ambiance/fn_airbaseRequestQueueParkedAsset.sqf"

require_pattern "$RPC" \
    "if \(!isServer\) exitWith" \
    "RPC: isServer guard present"

require_pattern "$RPC" \
    "ARC_fnc_airbaseRuntimeEnabled" \
    "RPC: runtime-enabled guard present"

require_pattern "$RPC" \
    "remoteExecutedOwner" \
    "RPC: remoteExecutedOwner captured"

require_pattern "$RPC" \
    "_reoOwner" \
    "RPC: _reoOwner variable used"

require_pattern "$RPC" \
    "ARC_fnc_rpcValidateSender" \
    "RPC: rpcValidateSender called"

require_pattern "$RPC" \
    "_reoOwner\] call ARC_fnc_rpcValidateSender" \
    "RPC: _reoOwner passed as 6th param to rpcValidateSender"

require_pattern "$RPC" \
    "ARC_fnc_airbaseTowerAuthorize" \
    "RPC: airbaseTowerAuthorize called"

require_pattern "$RPC" \
    '"APPROVE"' \
    "RPC: APPROVE authorization level used"

require_pattern "$RPC" \
    "airbase_v1_rt" \
    "RPC: reads airbase_v1_rt runtime HashMap"

require_pattern "$RPC" \
    "airbase_v1_seq" \
    "RPC: uses flight ID sequence counter"

require_pattern "$RPC" \
    '"MANUAL_ATC"' \
    "RPC: sets source=MANUAL_ATC in record meta"

require_pattern "$RPC" \
    '"manualOverride", true' \
    "RPC: sets manualOverride=true in record meta"

require_pattern "$RPC" \
    "ARC_fnc_airbaseBuildRouteDecision" \
    "RPC: calls airbaseBuildRouteDecision"

require_pattern "$RPC" \
    '"airbase_v1_queue"' \
    "RPC: persists queue via stateSet"

require_pattern "$RPC" \
    '"airbase_v1_records"' \
    "RPC: persists records via stateSet"

require_pattern "$RPC" \
    "ARC_fnc_intelLog" \
    "RPC: logs ops event via intelLog"

require_pattern "$RPC" \
    '\[ARC\]\[AIRBASE\]\[RAMP\]' \
    "RPC: uses structured log prefix [ARC][AIRBASE][RAMP]"

# sqflint compat: no banned constructs
require_absent "$RPC" \
    "findIf\s*\{" \
    "RPC: no findIf (sqflint compat)"

require_absent "$RPC" \
    'getOrDefault\s*\[' \
    "RPC: no method-style getOrDefault (sqflint compat)"

require_absent "$RPC" \
    "isNotEqualTo" \
    "RPC: no isNotEqualTo (sqflint compat)"

echo ""

# -----------------------------------------------------------------------
# 2. Client wrapper
# -----------------------------------------------------------------------
echo "-- Section 2: Client wrapper --"

CLIENT="functions/ambiance/fn_airbaseClientQueueParkedAsset.sqf"

require_pattern "$CLIENT" \
    "hasInterface" \
    "Client wrapper: hasInterface guard present"

require_pattern "$CLIENT" \
    'remoteExec \["ARC_fnc_airbaseRequestQueueParkedAsset", 2\]' \
    "Client wrapper: remoteExecs to server (target=2)"

require_pattern "$CLIENT" \
    "player" \
    "Client wrapper: passes player as caller"

echo ""

# -----------------------------------------------------------------------
# 3. Broadcast state: parkedAssets in snapshot
# -----------------------------------------------------------------------
echo "-- Section 3: publicBroadcastState parkedAssets --"

BCAST="functions/core/fn_publicBroadcastState.sqf"

require_pattern "$BCAST" \
    '"parkedAssets"' \
    "Broadcast: parkedAssets key in airbaseUiSnapshot"

require_pattern "$BCAST" \
    "_uiParkedAssets" \
    "Broadcast: _uiParkedAssets variable built"

require_pattern "$BCAST" \
    "airbase_v1_rt" \
    "Broadcast: reads airbase_v1_rt for parked assets"

require_pattern "$BCAST" \
    "_queuedAssetIds" \
    "Broadcast: filters out already-queued assets"

require_pattern "$BCAST" \
    "count _uiParkedAssets" \
    "Broadcast: parked count in change-detection key"

require_pattern "$BCAST" \
    "_fnHmGetBcast" \
    "Broadcast: uses compiled HashMap helper (_fnHmGetBcast)"

# No method-style getOrDefault in the new parked-assets block
require_absent "$BCAST" \
    "_rtBcastAssets.*getOrDefault\|_uiParkedAssets.*getOrDefault" \
    "Broadcast: no method-style getOrDefault in parked-assets block (sqflint compat)"

echo ""

# -----------------------------------------------------------------------
# 4. fn_airbaseTick: METT-TC priority selection
# -----------------------------------------------------------------------
echo "-- Section 4: fn_airbaseTick METT-TC priority --"

TICK="functions/ambiance/fn_airbaseTick.sqf"

require_pattern "$TICK" \
    "airbase_v1_assetDeparturePriorityOrder" \
    "Tick: reads airbase_v1_assetDeparturePriorityOrder config"

require_pattern "$TICK" \
    "_priorityOrder" \
    "Tick: _priorityOrder variable used"

require_pattern "$TICK" \
    "_priorityIdx" \
    "Tick: _priorityIdx index used for priority selection"

require_pattern "$TICK" \
    "selectRandom _candidates" \
    "Tick: selectRandom fallback preserved"

require_pattern "$TICK" \
    "_priorityIdx >= 0" \
    "Tick: priority index guards selectRandom fallback"

echo ""

# -----------------------------------------------------------------------
# 5. Console AIR paint: RAMP submode
# -----------------------------------------------------------------------
echo "-- Section 5: fn_uiConsoleAirPaint RAMP submode --"

PAINT="functions/ui/fn_uiConsoleAirPaint.sqf"

require_pattern "$PAINT" \
    '_modes pushBack "RAMP"' \
    "AirPaint: RAMP in _cycleModes"

require_pattern "$PAINT" \
    'in \["AIRFIELD_OPS".*"RAMP"' \
    "AirPaint: RAMP in valid submode guard"

require_pattern "$PAINT" \
    'case "RAMP":' \
    "AirPaint: case RAMP in list switch"

require_pattern "$PAINT" \
    '"parkedAssets"' \
    "AirPaint: reads parkedAssets from snapshot"

require_pattern "$PAINT" \
    'case "ASSET":' \
    "AirPaint: case ASSET in detail panel"

require_pattern "$PAINT" \
    '"QUEUE DEPARTURE"' \
    "AirPaint: QUEUE DEPARTURE button label in RAMP/ASSET"

require_pattern "$PAINT" \
    '"Ramp Control"' \
    "AirPaint: Ramp Control mode title"

require_pattern "$PAINT" \
    'case "RAMP_HDR":' \
    "AirPaint: case RAMP_HDR in detail panel"

echo ""

# -----------------------------------------------------------------------
# 6. Console AIR primary action: RAMP case
# -----------------------------------------------------------------------
echo "-- Section 6: fn_uiConsoleActionAirPrimary RAMP --"

PRIMARY="functions/ui/fn_uiConsoleActionAirPrimary.sqf"

require_pattern "$PRIMARY" \
    'case "RAMP":' \
    "AirPrimary: case RAMP in submode switch"

require_pattern "$PRIMARY" \
    'ARC_fnc_airbaseClientQueueParkedAsset' \
    "AirPrimary: calls airbaseClientQueueParkedAsset for ASSET row"

require_pattern "$PRIMARY" \
    '_canAirQueueManage' \
    "AirPrimary: checks _canAirQueueManage before queuing"

echo ""

# -----------------------------------------------------------------------
# 7. Console AIR secondary action: RAMP in cycle
# -----------------------------------------------------------------------
echo "-- Section 7: fn_uiConsoleActionAirSecondary RAMP --"

SECONDARY="functions/ui/fn_uiConsoleActionAirSecondary.sqf"

require_pattern "$SECONDARY" \
    '_modes pushBack "RAMP"' \
    "AirSecondary: RAMP in _cycleModes"

require_pattern "$SECONDARY" \
    'in \["AIRFIELD_OPS".*"RAMP"' \
    "AirSecondary: RAMP in valid submode guard"

require_pattern "$SECONDARY" \
    'case "RAMP":' \
    "AirSecondary: case RAMP in switch"

echo ""

# -----------------------------------------------------------------------
# 8. CfgFunctions registration
# -----------------------------------------------------------------------
echo "-- Section 8: CfgFunctions registration --"

CFG="config/CfgFunctions.hpp"

require_pattern "$CFG" \
    "class airbaseRequestQueueParkedAsset" \
    "CfgFunctions: airbaseRequestQueueParkedAsset registered"

require_pattern "$CFG" \
    "class airbaseClientQueueParkedAsset" \
    "CfgFunctions: airbaseClientQueueParkedAsset registered"

echo ""

# -----------------------------------------------------------------------
# 9. CfgRemoteExec allowlist
# -----------------------------------------------------------------------
echo "-- Section 9: CfgRemoteExec allowlist --"

REMEX="config/CfgRemoteExec.hpp"

require_pattern "$REMEX" \
    "ARC_fnc_airbaseRequestQueueParkedAsset.*allowedTargets = 2" \
    "CfgRemoteExec: ARC_fnc_airbaseRequestQueueParkedAsset allowlisted with target=2"

echo ""

# -----------------------------------------------------------------------
# Final result
# -----------------------------------------------------------------------
if $pass; then
    echo "=== ALL CHECKS PASSED ==="
    exit 0
else
    echo "=== ONE OR MORE CHECKS FAILED ==="
    exit 1
fi
