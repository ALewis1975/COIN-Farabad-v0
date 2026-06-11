#!/usr/bin/env bash
set -euo pipefail

# Static contract checks for the transient incident/lead/civic overlay spawning
# phase (issue #633, steps 4/7/8). Verifies the overlay spawner is server-only,
# toggle-gated, cleanup-owned (single state key written at init and cleared at
# cleanup), registered in CfgFunctions, and free of known sqflint-compat
# pitfalls. The default-off toggle keeps the change gameplay-neutral.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESOLVE="$ROOT/functions/world/fn_worldSpawnPatternResolve.sqf"
ROLE="$ROOT/functions/world/fn_worldSpawnRoleResolve.sqf"
APPLY="$ROOT/functions/world/fn_worldSpawnOverlayApply.sqf"
INITACT="$ROOT/functions/core/fn_execInitActive.sqf"
CLEANUP="$ROOT/functions/core/fn_execCleanupActive.sqf"
CFG="$ROOT/config/CfgFunctions.hpp"
INIT="$ROOT/initServer.sqf"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

# --- Files exist ----------------------------------------------------------
for f in "$RESOLVE" "$ROLE" "$APPLY" "$INITACT" "$CLEANUP" "$CFG" "$INIT"; do
    [[ -f "$f" ]] || fail "required file missing: $f"
done
pass "overlay spawner files exist"

# --- CfgFunctions registration (function-packaging requirement) -----------
for fn in worldSpawnPatternResolve worldSpawnRoleResolve worldSpawnOverlayApply; do
    grep -q "class $fn" "$CFG" || fail "$fn not registered in CfgFunctions.hpp"
done
pass "overlay functions registered in CfgFunctions"

# --- Server-only + toggle gate (authority + gameplay-neutral default) ------
grep -q 'isServer' "$APPLY" || fail "overlay spawner missing isServer guard"
grep -q 'ARC_incidentOverlaySpawnsEnabled' "$APPLY" || fail "overlay spawner not gated by ARC_incidentOverlaySpawnsEnabled"
pass "overlay spawner is server-only and toggle-gated"

# Toggle must be seeded ON by default in initServer.sqf (post live-run validation),
# while remaining overridable (isNil-guarded) for rollback.
grep -q '"ARC_incidentOverlaySpawnsEnabled", true' "$INIT" \
    || fail "ARC_incidentOverlaySpawnsEnabled not defaulted true in initServer.sqf"
grep -q 'isNil { missionNamespace getVariable "ARC_incidentOverlaySpawnsEnabled" }' "$INIT" \
    || fail "ARC_incidentOverlaySpawnsEnabled seed is not isNil-guarded (not overridable)"
pass "overlay toggle defaults true and remains overridable"

# Performance caps must be seeded.
for cap in ARC_overlayMaxAiPerIncident ARC_overlayMaxHostilesPerIncident ARC_overlayMaxObjectsPerIncident; do
    grep -q "$cap" "$INIT" || fail "performance cap $cap missing in initServer.sqf"
done
pass "overlay performance caps seeded in initServer.sqf"

# --- Single-writer cleanup contract: one state key, written at init, ------
# --- cleared at cleanup. --------------------------------------------------
grep -q 'activeOverlaySpawnNetIds' "$INITACT" \
    || fail "execInitActive does not write activeOverlaySpawnNetIds"
grep -q 'activeOverlaySpawnNetIds' "$CLEANUP" \
    || fail "execCleanupActive does not read activeOverlaySpawnNetIds"
# Cleanup must clear the key back to an empty array (single-writer reset).
grep -Eq 'activeOverlaySpawnNetIds".*\[\]|\[\].*activeOverlaySpawnNetIds' "$CLEANUP" \
    || fail "execCleanupActive does not clear activeOverlaySpawnNetIds"
pass "overlay NetId state key written at init and cleared at cleanup"

# The init spawn block must be guarded by the same toggle (gameplay-neutral).
grep -q 'ARC_incidentOverlaySpawnsEnabled' "$INITACT" \
    || fail "execInitActive overlay block not gated by ARC_incidentOverlaySpawnsEnabled"
pass "execInitActive overlay block is toggle-gated"

# --- Placement strategies: rooftop/tower + district_centroid (issue #633 c) -
# The new strategies must be present in the apply dispatch and must reuse the
# existing server-local registries rather than introducing new scans.
for label in 'rooftop' 'tower' 'district_centroid'; do
    grep -q "\"$label\"" "$APPLY" || fail "placement strategy '$label' missing from overlay apply"
done
pass "overlay apply implements rooftop/tower + district_centroid placement"

for reg in 'ARC_worldBuildingSlots' 'civsub_v1_districts'; do
    grep -q "$reg" "$APPLY" || fail "overlay apply does not reuse registry $reg for slot/centroid placement"
done
pass "overlay apply reuses building-slot + district registries (no new scans)"

# No new expensive scans introduced for placement: BIS_fnc_buildingPositions
# must NOT appear, and nearestObjects is only allowed for the pre-existing
# one-time parked-vehicle collision guard (at most one occurrence).
if grep -q 'BIS_fnc_buildingPositions' "$APPLY"; then
    fail "overlay apply must not call BIS_fnc_buildingPositions (reuse ARC_worldBuildingSlots)"
fi
no_calls=$(grep -cE 'nearestObjects[[:space:]]*\[' "$APPLY" || true)
if [[ "$no_calls" -gt 1 ]]; then
    fail "overlay apply has $no_calls nearestObjects calls; only the parked-vehicle collision guard is allowed"
fi
pass "overlay apply introduces no new building/nearestObjects scans"


for f in "$RESOLVE" "$ROLE" "$APPLY"; do
    for badpat in 'findIf' 'isNotEqualTo' 'toUpperANSI' 'toLowerANSI'; do
        if grep -qE "\b$badpat\b" "$f"; then
            fail "sqflint-compat: $badpat used in $(basename "$f")"
        fi
    done
    # Hash-index operator '#' must not be used.
    if grep -qE '[A-Za-z0-9_\)\]] # [0-9]' "$f"; then
        fail "sqflint-compat: '#' indexing used in $(basename "$f")"
    fi
    # Bare createHashMapFromArray (not compiled) is banned.
    if grep -E 'createHashMapFromArray' "$f" | grep -vq 'compile'; then
        fail "sqflint-compat: bare createHashMapFromArray in $(basename "$f")"
    fi
    # Method-style getOrDefault is banned; only the compiled helper form allowed.
    if grep -E 'getOrDefault' "$f" | grep -vqE 'compile|call _hg'; then
        fail "sqflint-compat: method-style getOrDefault in $(basename "$f")"
    fi
done
pass "overlay SQF avoids known sqflint-compat pitfalls"

echo "[OK] spawn_pattern_overlay_contract_checks: all checks passed"
