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

# Toggle must default OFF in initServer.sqf.
grep -q '"ARC_incidentOverlaySpawnsEnabled", false' "$INIT" \
    || fail "ARC_incidentOverlaySpawnsEnabled not defaulted false in initServer.sqf"
pass "overlay toggle defaults false (gameplay-neutral)"

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

# --- sqflint-compat: changed SQF must avoid known parser-compat pitfalls ---
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
