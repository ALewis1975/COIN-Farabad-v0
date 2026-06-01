#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAT="$ROOT/data/coin_civic_mission_catalog.sqf"
BUILD="$ROOT/functions/core/fn_incidentCatalogBuild.sqf"
CREATE="$ROOT/functions/core/fn_incidentCreate.sqf"
SEED="$ROOT/functions/core/fn_incidentSeedQueue.sqf"
THREAT="$ROOT/functions/threat/fn_threatScheduleEvent.sqf"
CFG="$ROOT/config/CfgFunctions.hpp"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

[[ -f "$CAT" ]] || fail "structured civic mission catalog is missing"
[[ -f "$BUILD" ]] || fail "incident catalog builder is missing"
pass "structured civic mission catalog files exist"

grep -q 'class incidentCatalogBuild' "$CFG" || fail "incidentCatalogBuild not registered in CfgFunctions"
grep -q 'ARC_fnc_incidentCatalogBuild' "$CREATE" || fail "incidentCreate does not use incidentCatalogBuild"
grep -q 'ARC_fnc_incidentCatalogBuild' "$SEED" || fail "incidentSeedQueue does not use incidentCatalogBuild"
pass "catalog builder is registered and used by incident creation paths"

grep -q 'activeIncidentMissionMeta' "$CREATE" || fail "incidentCreate does not persist mission metadata"
grep -q 'activeIncidentMissionMeta' "$ROOT/functions/core/fn_stateInit.sqf" || fail "stateInit lacks activeIncidentMissionMeta default"
pass "selected civic mission metadata is persisted with active incidents"

for field in id missionSet subtype incidentType displayName locations siteTypes districts civsubFactors endState threatHooks outcomeDeltas; do
    grep -q "\[\"$field\"" "$CAT" || fail "catalog missing required field: $field"
done
pass "catalog records declare required metadata fields"

if grep -q '"incidentType", "CIVIL_' "$CAT"; then
    fail "catalog must keep top-level incidentType reusable; use subtype for named civic variants"
fi

python3 - "$CAT" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
allowed_types = {"CIVIL", "KLE", "CHECKPOINT", "RECON", "LOGISTICS", "ESCORT", "ROUTE_CLEARANCE"}
allowed_end = {"HOLD", "ARRIVE_HOLD", "INTERACT", "CONVOY", "ROUTE_RECON"}
for typ in re.findall(r'\["incidentType",\s*"([^"]+)"\]', text):
    if typ not in allowed_types:
        raise SystemExit(f"unsupported civic catalog incidentType: {typ}")
for end in re.findall(r'\["endState",\s*"([^"]+)"\]', text):
    if end not in allowed_end:
        raise SystemExit(f"unsupported civic catalog endState: {end}")
if re.search(r'"marker_\d+"', text):
    raise SystemExit("civic catalog should not reference legacy marker_<n> aliases")
print("[PASS] catalog uses reusable incident types, known end states, and canonical marker refs")
PY

if grep -q 'district_%1_obj' "$THREAT"; then
    fail "threatScheduleEvent still falls back to legacy district_<id>_obj marker"
fi
grep -q 'civsubDistrictsGetById' "$THREAT" || fail "threatScheduleEvent does not resolve CIVSUB district records"
grep -q '"centroid"' "$THREAT" || fail "threatScheduleEvent does not use CIVSUB centroid fallback"
pass "threat district fallback uses CIVSUB centroids instead of legacy markers"
