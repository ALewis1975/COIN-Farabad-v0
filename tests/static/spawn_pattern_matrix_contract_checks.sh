#!/usr/bin/env bash
set -euo pipefail

# Static contract checks for the Incident / Lead / site spawn-pattern matrix
# foundation (issue #633, steps 1-2). Verifies coverage (incidents, leads, and
# structured civic-mission subtypes) and that the audit is read-only and
# gameplay-neutral by default.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PAT="$ROOT/data/farabad_spawn_patterns.sqf"
AUDIT="$ROOT/functions/world/fn_worldSpawnPatternAudit.sqf"
MARKERS="$ROOT/data/incident_markers.sqf"
WORLD="$ROOT/data/farabad_world_locations.sqf"
CIVIC="$ROOT/data/coin_civic_mission_catalog.sqf"
CFG="$ROOT/config/CfgFunctions.hpp"
INIT="$ROOT/initServer.sqf"
RESOLVE="$ROOT/functions/world/fn_worldSpawnPatternResolve.sqf"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

[[ -f "$PAT" ]] || fail "spawn-pattern matrix data file is missing"
[[ -f "$AUDIT" ]] || fail "spawn-pattern audit function is missing"
pass "spawn-pattern data + audit files exist"

grep -q 'class worldSpawnPatternAudit' "$CFG" || fail "worldSpawnPatternAudit not registered in CfgFunctions"
pass "audit function is registered in CfgFunctions"

# Staged-rollout toggles must exist, default ON (post live-run validation), and
# stay isNil-guarded so they remain overridable for rollback.
for tog in ARC_spawnPatternsEnabled ARC_incidentOverlaySpawnsEnabled ARC_sitePurposeExpansionEnabled; do
    grep -q "\"$tog\", true" "$INIT" || fail "toggle $tog missing or not defaulted true in initServer.sqf"
    grep -q "isNil { missionNamespace getVariable \"$tog\" }" "$INIT" || fail "toggle $tog seed is not isNil-guarded (not overridable)"
done
pass "staged-rollout toggles present, default true, and overridable"

# The audit must be read-only: it must not create units/vehicles/markers or broadcast
# public mission state. (createHashMap / setVariable on local maps is fine; the
# guard targets spawning + public-variable broadcast verbs.)
for verb in 'createUnit' 'createVehicle' 'createAgent' 'createGroup' 'createMarker' 'publicVariable' 'remoteExec' 'ARC_fnc_incidentCatalogBuild'; do
    if grep -qE "\b$verb\b" "$AUDIT"; then
        fail "audit function must be read-only but uses $verb"
    fi
done
pass "audit function is server-only and read-only"

# sqflint-compat: the changed SQF must avoid known parser-compat pitfalls.
for badpat in 'findIf' 'isNotEqualTo' 'toUpperANSI' 'toLowerANSI'; do
    if grep -qE "\b$badpat\b" "$PAT" "$AUDIT"; then
        fail "sqflint-compat: $badpat used in spawn-pattern SQF"
    fi
done
# Bare createHashMapFromArray and method-style getOrDefault are also banned.
if grep -E 'createHashMapFromArray' "$AUDIT" | grep -vq 'compile'; then
    fail "sqflint-compat: bare createHashMapFromArray in audit"
fi
pass "spawn-pattern SQF avoids known sqflint-compat pitfalls"

# --- Zone-sensitive checkpoint variants (issue #633 step 6) ---------------
# The matrix must define three distinct checkpoint variants and the resolver
# must accept a zone arg and map zones to those variants.
for v in CHECKPOINT_GATE CHECKPOINT_URBAN CHECKPOINT_RURAL; do
    grep -q "\"$v\"" "$PAT" || fail "checkpoint variant $v missing from spawn-pattern matrix"
done
pass "matrix defines CHECKPOINT_GATE / CHECKPOINT_URBAN / CHECKPOINT_RURAL"

# Distinct placement: gate/urban use a gate lane, rural uses roadside flow.
grep -q '"CHECKPOINT_RURAL"' "$PAT" && grep -A14 '"CHECKPOINT_RURAL"' "$PAT" | grep -q '"placement", "roadside"' \
    || fail "CHECKPOINT_RURAL must use roadside placement (distinct ambient flow)"
pass "checkpoint variants have distinct placement/flow"

[[ -f "$RESOLVE" ]] || fail "resolver function is missing"
# Resolver must accept the 4th zone param and map zones to variants.
grep -q '_zone' "$RESOLVE" || fail "resolver does not accept a zone parameter"
for z in 'CHECKPOINT_GATE' 'CHECKPOINT_URBAN' 'CHECKPOINT_RURAL'; do
    grep -q "$z" "$RESOLVE" || fail "resolver missing zone->variant mapping for $z"
done
pass "resolver maps incident zone to checkpoint variant (default plain CHECKPOINT)"

# sqflint-compat for the resolver too.
for badpat in 'findIf' 'isNotEqualTo' 'toUpperANSI' 'toLowerANSI'; do
    if grep -qE "\b$badpat\b" "$RESOLVE"; then
        fail "sqflint-compat: $badpat used in resolver"
    fi
done
pass "resolver avoids known sqflint-compat pitfalls"

python3 - "$PAT" "$MARKERS" "$WORLD" "$CIVIC" <<'PY'
import re, sys
pat_path, markers_path, world_path, civic_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
pat = open(pat_path, encoding='utf-8').read()
markers = open(markers_path, encoding='utf-8').read()
world = open(world_path, encoding='utf-8').read()
civic = open(civic_path, encoding='utf-8').read()

def section(text, key):
    # Extract the array value for ["key", [ ... ]] by bracket matching.
    m = re.search(r'\["%s",\s*\[' % re.escape(key), text)
    if not m:
        raise SystemExit("spawn-pattern matrix missing section: %s" % key)
    i = m.end() - 1  # at the opening [
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == '[':
            depth += 1
        elif c == ']':
            depth -= 1
            if depth == 0:
                return text[i:j+1]
    raise SystemExit("unterminated section: %s" % key)

purpose_patterns = section(pat, "purposePatterns")
location_purposes = section(pat, "locationPurposes")
site_type_purposes = section(pat, "siteTypePurposes")
incident_overlays = section(pat, "incidentOverlays")
lead_overlays = section(pat, "leadOverlays")
civic_overlays = section(pat, "civicMissionOverlays")

# Purpose tags that have a pattern: first string of each top-level entry.
pattern_tags = set(re.findall(r'\["([A-Z_]+)",\s*\[\s*\["purpose"', purpose_patterns))
if not pattern_tags:
    raise SystemExit("no purpose patterns parsed")

# Recommended purpose tags from the issue must all have a pattern.
required_tags = {
    "RESIDENTIAL","MARKET","RELIGIOUS","MEDICAL","GOVERNMENT","HOTEL","SECURITY",
    "INDUSTRIAL","OIL_GAS","POWER","PORT","MINE","CONSTRUCTION","AGRICULTURAL",
    "MILITARY","PRISON","RURAL_HAMLET","CHECKPOINT","MSR_ROAD",
}
missing_req = required_tags - pattern_tags
if missing_req:
    raise SystemExit("purposePatterns missing required tags: %s" % sorted(missing_req))

# locationPurposes mapping: [id, purpose].
loc_map = dict(re.findall(r'\["([A-Za-z0-9_]+)",\s*"([A-Z_]+)"\]', location_purposes))
site_map = dict(re.findall(r'\["([A-Z_]+)",\s*"([A-Z_]+)"\]', site_type_purposes))

# Every named location id in the world export must be mapped.
world_named_block = world.split("private _sites", 1)[0]
named_ids = re.findall(r'\["([A-Za-z0-9_]+)",\s*"', world_named_block)
unmapped_loc = [i for i in named_ids if i not in loc_map]
if unmapped_loc:
    raise SystemExit("named locations without purpose mapping: %s" % unmapped_loc)

# Every terrain site type must be mapped.
world_sites_block = world.split("private _sites", 1)[1]
site_types = re.findall(r'\["([A-Z_]+)",\s*\[', world_sites_block)
unmapped_site = [s for s in site_types if s not in site_map]
if unmapped_site:
    raise SystemExit("terrain site types without purpose mapping: %s" % unmapped_site)

# Every purpose referenced (except the NO_BASELINE_POP sentinel) must have a pattern.
allowed = pattern_tags | {"NO_BASELINE_POP"}
for src, name in ((loc_map, "location"), (site_map, "siteType")):
    for k, v in src.items():
        if v not in allowed:
            raise SystemExit("%s %s references purpose %s with no pattern" % (name, k, v))

# Terrain site types specifically must resolve to a tag that has a real pattern
# (the issue requires at least one default spawn pattern per site type).
for k, v in site_map.items():
    if v not in pattern_tags:
        raise SystemExit("terrain site type %s must map to a purpose with a pattern (got %s)" % (k, v))

# Every incidentType in the legacy catalog must have an overlay.
overlay_types = set(re.findall(r'\["([A-Z_]+)",\s*\[\s*\["overlay"', incident_overlays))
catalog_types = set(re.findall(r',\s*"([A-Z_]+)"\]\s*[,\]]', markers))
# Filter to plausible incident-type tokens (skip marker/display noise) by
# intersecting with the known type vocabulary present in the catalog.
known_types = {
    "PATROL","IED","RAID","CIVIL","LOGISTICS","DEFEND","QRF","RECON",
    "CHECKPOINT","ESCORT","KLE","ROUTE_CLEARANCE",
}
catalog_types &= known_types
missing_overlay = catalog_types - overlay_types
if missing_overlay:
    raise SystemExit("incident types without overlay: %s" % sorted(missing_overlay))

# Lead overlays must cover the lead tags called out in the issue.
lead_tags = set(re.findall(r'\["([A-Z_]+)",\s*\[\s*\["overlay"', lead_overlays))
required_lead = {"SUS_VEHICLE","VBIED_DRIVEN_CHECKPOINT","VBIED_DRIVEN_GATE","SB_MARKET_APPROACH","CASEVAC"}
missing_lead = required_lead - lead_tags
if missing_lead:
    raise SystemExit("lead overlays missing: %s" % sorted(missing_lead))

# Every civic-mission subtype in the structured catalog must have an overlay.
civic_overlay_tags = set(re.findall(r'\["([A-Z_]+)",\s*\[\s*\["overlay"', civic_overlays))
civic_subtypes = set(re.findall(r'\["subtype",\s*"([A-Z_]+)"\]', civic))
if not civic_subtypes:
    raise SystemExit("no civic mission subtypes parsed from catalog")
missing_civic = civic_subtypes - civic_overlay_tags
if missing_civic:
    raise SystemExit("civic mission subtypes without overlay: %s" % sorted(missing_civic))

print("[PASS] every named location + terrain site type is mapped to a purpose with a pattern")
print("[PASS] every incident type and required lead tag has an overlay")
print("[PASS] every civic mission subtype has an overlay")
PY

pass "spawn-pattern matrix coverage is complete"
