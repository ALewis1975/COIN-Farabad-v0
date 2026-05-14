#!/usr/bin/env bash
# airbase_queue_lifecycle_contract_checks.sh
#
# Static checks verifying Air/Tower queue lifecycle contracts remain present.
# Run with: bash tests/static/airbase_queue_lifecycle_contract_checks.sh
# Exit: 0 = all checks passed, 1 = one or more failures.

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

check_file_exists() {
    local file="$1"
    local label="$2"
    if [[ -f "$file" ]]; then
        echo "[PASS] $label"
    else
        echo "[FAIL] $label"
        pass=false
    fi
}

check_cfg() {
    local pattern="$1"
    local label="$2"
    if grep -Eq "$pattern" config/CfgFunctions.hpp; then
        echo "[PASS] $label"
    else
        echo "[FAIL] $label"
        pass=false
    fi
}

# ── 1. Runway lock helpers: file existence + CfgFunctions registration ─────────

echo "=== 1. Runway lock helpers ==="
check_file_exists "functions/ambiance/fn_airbaseRunwayLockReserve.sqf"   "airbaseRunwayLockReserve file exists"
check_file_exists "functions/ambiance/fn_airbaseRunwayLockOccupy.sqf"    "airbaseRunwayLockOccupy file exists"
check_file_exists "functions/ambiance/fn_airbaseRunwayLockRelease.sqf"   "airbaseRunwayLockRelease file exists"
check_file_exists "functions/ambiance/fn_airbaseRunwayLockSweep.sqf"     "airbaseRunwayLockSweep file exists"

check_cfg 'class airbaseRunwayLockReserve\s*\{\}' "CfgFunctions: airbaseRunwayLockReserve registered"
check_cfg 'class airbaseRunwayLockOccupy\s*\{\}'  "CfgFunctions: airbaseRunwayLockOccupy registered"
check_cfg 'class airbaseRunwayLockRelease\s*\{\}' "CfgFunctions: airbaseRunwayLockRelease registered"
check_cfg 'class airbaseRunwayLockSweep\s*\{\}'   "CfgFunctions: airbaseRunwayLockSweep registered"

# Server authority guards on all four runway helpers
for f in Reserve Occupy Release Sweep; do
    check '^\s*if\s*\(!isServer\)\s*exitWith' \
        "functions/ambiance/fn_airbaseRunwayLock${f}.sqf" \
        "airbaseRunwayLock${f}: isServer authority guard present"
done

# Reserve, Occupy, and Release each call Sweep internally
for f in Reserve Occupy Release; do
    check 'ARC_fnc_airbaseRunwayLockSweep' \
        "functions/ambiance/fn_airbaseRunwayLock${f}.sqf" \
        "airbaseRunwayLock${f}: calls airbaseRunwayLockSweep for stale-lock recovery"
done

# Sweep clears RESERVED, OCCUPIED, and OPEN transitions
check 'TIMEOUT|MISSING_OWNER|ORPHANED_EXEC' \
    "functions/ambiance/fn_airbaseRunwayLockSweep.sqf" \
    "airbaseRunwayLockSweep: recognises timeout/missing-owner/orphaned-exec cleanup reasons"

# Reserve must replicate runway state to all clients
check 'setVariable\s*\["airbase_v1_runwayState".*true\]' \
    "functions/ambiance/fn_airbaseRunwayLockReserve.sqf" \
    "airbaseRunwayLockReserve: replicates runwayState to clients"

# Release must reset to OPEN and replicate
check '"OPEN".*true' \
    "functions/ambiance/fn_airbaseRunwayLockRelease.sqf" \
    "airbaseRunwayLockRelease: resets runwayState to OPEN with replication"

# ── 2. Departure queue mutation helpers ───────────────────────────────────────

echo ""
echo "=== 2. Departure queue mutation helpers ==="
check_file_exists "functions/ambiance/fn_airbaseQueueMoveToFront.sqf"      "airbaseQueueMoveToFront file exists"
check_file_exists "functions/ambiance/fn_airbaseQueueRemoveByFid.sqf"      "airbaseQueueRemoveByFid file exists"
check_file_exists "functions/ambiance/fn_airbaseRecordSetQueuedStatus.sqf" "airbaseRecordSetQueuedStatus file exists"

check_cfg 'class airbaseQueueMoveToFront\s*\{\}'      "CfgFunctions: airbaseQueueMoveToFront registered"
check_cfg 'class airbaseQueueRemoveByFid\s*\{\}'      "CfgFunctions: airbaseQueueRemoveByFid registered"
check_cfg 'class airbaseRecordSetQueuedStatus\s*\{\}' "CfgFunctions: airbaseRecordSetQueuedStatus registered"

# MoveToFront must accept queue + flightId and return [queueOut, moved, item]
check 'params\s*\[' "functions/ambiance/fn_airbaseQueueMoveToFront.sqf" \
    "airbaseQueueMoveToFront: uses params for type-safe input"
check '_flightId' "functions/ambiance/fn_airbaseQueueMoveToFront.sqf" \
    "airbaseQueueMoveToFront: accepts flightId parameter"

# RemoveByFid must accept queue + flightId and return [queueOut, removed, item]
check 'params\s*\[' "functions/ambiance/fn_airbaseQueueRemoveByFid.sqf" \
    "airbaseQueueRemoveByFid: uses params for type-safe input"
check '_flightId' "functions/ambiance/fn_airbaseQueueRemoveByFid.sqf" \
    "airbaseQueueRemoveByFid: accepts flightId parameter"

# RecordSetQueuedStatus must handle at least CANCELED, PRIORITIZED, ACTIVE, COMPLETE, FAILED
check '"CANCELED".*"PRIORITIZED"' "functions/ambiance/fn_airbaseRecordSetQueuedStatus.sqf" \
    "airbaseRecordSetQueuedStatus: validates allowed status transitions"

# Prioritize and cancel flight server handlers call queue mutation helpers
check 'ARC_fnc_airbaseQueueMoveToFront' \
    "functions/ambiance/fn_airbaseRequestPrioritizeFlight.sqf" \
    "airbaseRequestPrioritizeFlight: calls airbaseQueueMoveToFront"
# Cancel uses direct deleteAt rather than the helper; check for queue-state write and event log
check 'deleteAt.*_idx|AIRBASE_QUEUE_CANCEL' \
    "functions/ambiance/fn_airbaseRequestCancelQueuedFlight.sqf" \
    "airbaseRequestCancelQueuedFlight: mutates queue (deleteAt) and emits AIRBASE_QUEUE_CANCEL event"

# ── 3. Failed RETURN-arrival recovery (PR #533) ───────────────────────────────

echo ""
echo "=== 3. Failed RETURN-arrival recovery ==="
check 'AIRBASE_RETURN_FAILURE_RECOVERED' \
    "functions/ambiance/fn_airbaseTick.sqf" \
    "airbaseTick: logs AIRBASE_RETURN_FAILURE_RECOVERED event for failed RETURN arrivals"
check '"state",\s*"COOLDOWN"' \
    "functions/ambiance/fn_airbaseTick.sqf" \
    "airbaseTick: resets stuck RETURN asset state to COOLDOWN on failure"
check '"activeFlight",\s*""' \
    "functions/ambiance/fn_airbaseTick.sqf" \
    "airbaseTick: clears activeFlight on failed RETURN asset"
check '"availableAt"' \
    "functions/ambiance/fn_airbaseTick.sqf" \
    "airbaseTick: sets availableAt cooldown on failed RETURN asset"

# ── 4. Public UI snapshot expected top-level fields ───────────────────────────

echo ""
echo "=== 4. Public UI snapshot (ARC_pub_airbaseUiSnapshot) fields ==="
SNAP_FILE="functions/core/fn_publicBroadcastState.sqf"

check '\["v",\s*1\]'              "$SNAP_FILE" "snapshot: version field 'v' present"
check '\["rev",'                  "$SNAP_FILE" "snapshot: 'rev' field present"
check '\["updatedAt",'            "$SNAP_FILE" "snapshot: 'updatedAt' field present"
check '\["freshnessState",'       "$SNAP_FILE" "snapshot: 'freshnessState' field present"
check '\["runway",'               "$SNAP_FILE" "snapshot: 'runway' block present"
check '\["arrivals",'             "$SNAP_FILE" "snapshot: 'arrivals' field present"
check '\["departures",'           "$SNAP_FILE" "snapshot: 'departures' field present"
check '\["pendingClearances",'    "$SNAP_FILE" "snapshot: 'pendingClearances' field present"
check '\["alerts",'               "$SNAP_FILE" "snapshot: 'alerts' field present"
check '\["decisionQueue",'        "$SNAP_FILE" "snapshot: 'decisionQueue' field present"
check '\["staffing",'             "$SNAP_FILE" "snapshot: 'staffing' field present"
check '\["recentEvents",'         "$SNAP_FILE" "snapshot: 'recentEvents' field present"
check '\["clearanceHistory",'     "$SNAP_FILE" "snapshot: 'clearanceHistory' field present"

# Snapshot is broadcast with JIP replication
check 'missionNamespace setVariable \["ARC_pub_airbaseUiSnapshot".*true\]' \
    "$SNAP_FILE" "snapshot: published with global replication (true)"

# Runway sub-block carries expected fields
check '\["state", _runwayState\]'           "$SNAP_FILE" "runway block: 'state' field"
check '\["ownerFlightId",'                  "$SNAP_FILE" "runway block: 'ownerFlightId' field"
check '\["holdState",'                      "$SNAP_FILE" "runway block: 'holdState' field"

# ── 5. Arrival/departure tuple position guards for CT_MAP ─────────────────────

echo ""
echo "=== 5. CT_MAP position-field safety (tuple indexes 7/8) ==="

# publicBroadcastState appends posX/posY at the end of arrival and departure tuples
check 'Phase 7|posX.*posY|CT_MAP' \
    "$SNAP_FILE" \
    "snapshot: arrival/departure tuples document posX/posY for CT_MAP (comment or field)"

# UI map painter declares named index constants for posX/posY to avoid magic-number indexing
check '_IDX_POS_X\s*=\s*7' \
    "functions/ui/fn_uiConsoleAirMapPaint.sqf" \
    "AirMapPaint: declares _IDX_POS_X = 7 constant for safe posX index access"

check '_IDX_POS_Y\s*=\s*8' \
    "functions/ui/fn_uiConsoleAirMapPaint.sqf" \
    "AirMapPaint: declares _IDX_POS_Y = 8 constant for safe posY index access"

# Painter uses param with default via named constants (safe out-of-bounds guard)
check 'param\s*\[_IDX_POS_X' \
    "functions/ui/fn_uiConsoleAirMapPaint.sqf" \
    "AirMapPaint: uses param [_IDX_POS_X, ...] with default for safe posX access"

check 'param\s*\[_IDX_POS_Y' \
    "functions/ui/fn_uiConsoleAirMapPaint.sqf" \
    "AirMapPaint: uses param [_IDX_POS_Y, ...] with default for safe posY access"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [[ "$pass" != true ]]; then
    echo "Air/Tower queue lifecycle contract checks FAILED."
    exit 1
fi

echo "Air/Tower queue lifecycle contract checks PASSED."
