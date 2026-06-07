#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HUD="$ROOT/config/RscTitles.hpp"
ADD_ACTION="$ROOT/functions/core/fn_clientAddObjectiveAction.sqf"
CLIENT_INTERACT="$ROOT/functions/core/fn_clientObjectiveInteract.sqf"
COMPLETE="$ROOT/functions/core/fn_execObjectiveComplete.sqf"
EXEC_INIT="$ROOT/functions/core/fn_execInitActive.sqf"
CLEANUP="$ROOT/functions/core/fn_execCleanupActive.sqf"
STATE="$ROOT/functions/core/fn_stateInit.sqf"
CONVOY_WPS="$ROOT/functions/logistics/fn_convoyApplyRouteWps.sqf"
CONVOY_TICK="$ROOT/functions/logistics/fn_execTickConvoy.sqf"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -q 'x = safeZoneX + 0\.01;' "$HUD" || fail "Active Task HUD is not anchored to upper-left safeZone"
pass "Active Task HUD is anchored in the upper-left corner"

grep -q 'ARC_objectiveAddActionsEnabled", true' "$ADD_ACTION" || fail "objective addActions are not enabled by default"
pass "objective interactions are enabled by default"

grep -q '"CHECKPOINT_ACCESS"' "$EXEC_INIT" || fail "checkpoint access-control objective kind is not configured"
grep -q 'Process civil access checkpoint' "$EXEC_INIT" || fail "checkpoint access-control action text is missing"
grep -q 'ARC_checkpointAccessVehicleClassPool' "$EXEC_INIT" || fail "checkpoint access-control vehicle pool is missing"
grep -q '"CHECKPOINT_ACCESS": { "OPS" }' "$CLIENT_INTERACT" || fail "client interaction does not classify CHECKPOINT_ACCESS as OPS"
grep -q '"CHECKPOINT_ACCESS": { "OPS" }' "$COMPLETE" || fail "server completion does not classify CHECKPOINT_ACCESS as OPS"
pass "checkpoint access-control incidents have a physical interactable objective"

grep -q '"FOOD_WATER_DISTRIBUTION"' "$EXEC_INIT" || fail "food/water subtype is not recognized by execution init"
grep -q 'Distribute food and water' "$EXEC_INIT" || fail "food/water action text is missing"
grep -q 'ARC_civicFoodWaterCrowdCount' "$EXEC_INIT" || fail "food/water civilian crowd spawn is missing"
grep -q 'activeCivicObjectiveNetIds' "$STATE" || fail "civic objective actor state key is missing"
grep -q 'activeCivicObjectiveNetIds' "$CLEANUP" || fail "civic objective actors are not cleaned up"
pass "food/water incidents spawn visible aid recipients and clean them up"

grep -q 'ARC_convoyFinalWpRadiusM", 90' "$CONVOY_WPS" || fail "convoy final waypoint radius default was not relaxed"
grep -q '_finalWpRad \* 0\.75' "$CONVOY_WPS" || fail "convoy final waypoint dedupe does not scale with final radius"
grep -q 'ARC_convoyArrivalFileSlotRadiusM", 14' "$CONVOY_TICK" || fail "convoy arrival file slot radius default was not relaxed"
pass "convoy destination convergence uses relaxed final/parking tolerances"
