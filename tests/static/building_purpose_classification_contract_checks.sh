#!/usr/bin/env bash
set -euo pipefail

# Static contract checks for the building-purpose classification layer
# (issue #633 step 5). Verifies the classifier is server-only, toggle-gated,
# reuses the pre-scanned building-slot registry (no new scans), writes a
# non-broadcast server-local registry, is registered in CfgFunctions, wired
# into world init after the building-slot scan, and that the matrix can
# represent every issue-listed purpose tag.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASSIFY="$ROOT/functions/world/fn_worldBuildingPurposeClassify.sqf"
AUDIT="$ROOT/functions/world/fn_worldSpawnPatternAudit.sqf"
WORLDINIT="$ROOT/functions/world/fn_worldInit.sqf"
PAT="$ROOT/data/farabad_spawn_patterns.sqf"
CFG="$ROOT/config/CfgFunctions.hpp"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

for f in "$CLASSIFY" "$AUDIT" "$WORLDINIT" "$PAT" "$CFG"; do
    [[ -f "$f" ]] || fail "required file missing: $f"
done
pass "building-purpose classifier files exist"

# --- CfgFunctions registration (function-packaging requirement) -----------
grep -q 'class worldBuildingPurposeClassify' "$CFG" \
    || fail "worldBuildingPurposeClassify not registered in CfgFunctions.hpp"
pass "classifier registered in CfgFunctions"

# --- Server-only + toggle gate --------------------------------------------
grep -q 'isServer' "$CLASSIFY" || fail "classifier missing isServer guard"
grep -q 'ARC_spawnPatternsEnabled' "$CLASSIFY" \
    || fail "classifier not gated by ARC_spawnPatternsEnabled"
pass "classifier is server-only and gated by ARC_spawnPatternsEnabled"

# --- Reuses building-slot registry; introduces no new scans ----------------
grep -q 'ARC_worldBuildingSlots' "$CLASSIFY" \
    || fail "classifier does not reuse ARC_worldBuildingSlots"
for verb in 'BIS_fnc_buildingPositions' 'nearestObjects' 'nearRoads' 'nearestTerrainObjects'; do
    if grep -qE "\b$verb\b" "$CLASSIFY"; then
        fail "classifier must not introduce new scan ($verb); reuse pre-scanned registries"
    fi
done
pass "classifier reuses pre-scanned registries (no new scans)"

# --- Writes a non-broadcast server-local registry --------------------------
grep -q 'ARC_worldBuildingPurpose' "$CLASSIFY" \
    || fail "classifier does not write ARC_worldBuildingPurpose registry"
# The setVariable that writes the registry must NOT pass a public/broadcast flag.
if grep -E 'setVariable[[:space:]]*\[[[:space:]]*"ARC_worldBuildingPurpose"' "$CLASSIFY" | grep -q 'true\]'; then
    fail "ARC_worldBuildingPurpose must be server-local (no broadcast flag)"
fi
pass "classifier writes server-local (non-broadcast) registry"

# --- Wired into world init after the building-slot scan --------------------
grep -q 'ARC_fnc_worldBuildingPurposeClassify' "$WORLDINIT" \
    || fail "classifier not invoked from fn_worldInit.sqf"
python3 - "$WORLDINIT" <<'PY'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
scan = t.find('ARC_fnc_worldScanBuildingSlots')
classify = t.find('ARC_fnc_worldBuildingPurposeClassify')
if scan < 0 or classify < 0:
    raise SystemExit("worldInit missing scan or classify call")
if classify < scan:
    raise SystemExit("classifier must be invoked AFTER ARC_fnc_worldScanBuildingSlots")
print("[PASS] classifier runs after the building-slot scan")
PY

# --- Audit reports per-purpose building-slot coverage ----------------------
grep -q 'ARC_worldBuildingPurpose' "$AUDIT" \
    || fail "audit does not read ARC_worldBuildingPurpose for coverage report"
grep -q 'buildingPurposeCounts' "$AUDIT" \
    || fail "audit does not emit buildingPurposeCounts"
pass "audit reports per-purpose building-slot coverage + NONE warnings"

# --- Matrix can represent every issue-listed purpose tag -------------------
python3 - "$PAT" <<'PY'
import re, sys
pat = open(sys.argv[1], encoding='utf-8').read()

def section(text, key):
    m = re.search(r'\["%s",\s*\[' % re.escape(key), text)
    if not m:
        raise SystemExit("matrix missing section: %s" % key)
    i = m.end() - 1
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
pattern_tags = set(re.findall(r'\["([A-Z_]+)",\s*\[\s*\["purpose"', purpose_patterns))

required = {
    "RESIDENTIAL","MARKET","RELIGIOUS","MEDICAL","GOVERNMENT","HOTEL","SECURITY",
    "INDUSTRIAL","OIL_GAS","POWER","PORT","MINE","CONSTRUCTION","AGRICULTURAL",
    "MILITARY","PRISON","RURAL_HAMLET","CHECKPOINT","MSR_ROAD",
}
missing = required - pattern_tags
if missing:
    raise SystemExit("purposePatterns missing tags needed for classification: %s" % sorted(missing))

# The classification hints table must exist and reference only purposes that
# have a real pattern (so a hinted CONSTRUCTION/etc. tag is spawnable).
hints = section(pat, "buildingClassPurposeHints")
hint_tags = set(re.findall(r'\["[a-z_]+",\s*"([A-Z_]+)"\]', hints))
if not hint_tags:
    raise SystemExit("buildingClassPurposeHints parsed no entries")
bad = hint_tags - pattern_tags
if bad:
    raise SystemExit("buildingClassPurposeHints references purposes with no pattern: %s" % sorted(bad))
if "CONSTRUCTION" not in hint_tags:
    raise SystemExit("buildingClassPurposeHints must map a construction signal to CONSTRUCTION")
print("[PASS] every issue-listed purpose tag is representable; hints resolve to real patterns")
PY

# --- sqflint-compat: avoid known parser-compat pitfalls --------------------
for badpat in 'findIf' 'isNotEqualTo' 'toUpperANSI' 'toLowerANSI'; do
    if grep -qE "\b$badpat\b" "$CLASSIFY"; then
        fail "sqflint-compat: $badpat used in classifier"
    fi
done
if grep -E 'createHashMapFromArray' "$CLASSIFY" | grep -vq 'compile'; then
    fail "sqflint-compat: bare createHashMapFromArray in classifier"
fi
if grep -E 'getOrDefault' "$CLASSIFY" | grep -vqE 'compile|call _hg'; then
    fail "sqflint-compat: method-style getOrDefault in classifier"
fi
if grep -qE '[A-Za-z0-9_\)\]] # [0-9]' "$CLASSIFY"; then
    fail "sqflint-compat: '#' indexing used in classifier"
fi
pass "classifier avoids known sqflint-compat pitfalls"

echo "[OK] building_purpose_classification_contract_checks: all checks passed"
