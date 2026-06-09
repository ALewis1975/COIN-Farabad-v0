#!/usr/bin/env bash
set -euo pipefail

# Static contract checks for the SitePop purpose-expansion (issue #633, step 4).
#
# Verifies that:
#   1. The expansion is gated behind ARC_sitePurposeExpansionEnabled (default off),
#      so default behaviour is identical to the pre-expansion three-site mission.
#   2. The three original sites remain registered unconditionally.
#   3. Every expansion siteId / marker corresponds to a real named location +
#      ARC_loc_* marker in the world export, and aligns with the purpose mapping in
#      the spawn-pattern matrix (data/farabad_spawn_patterns.sqf).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TPL="$ROOT/data/farabad_site_templates.sqf"
WORLD="$ROOT/data/farabad_world_locations.sqf"
PAT="$ROOT/data/farabad_spawn_patterns.sqf"
INIT="$ROOT/initServer.sqf"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

[[ -f "$TPL" ]] || fail "site templates data file is missing"
[[ -f "$WORLD" ]] || fail "world locations data file is missing"
[[ -f "$PAT" ]] || fail "spawn-pattern matrix data file is missing"
pass "required data files exist"

# Toggle default must be OFF (gameplay-neutral by default).
grep -q '"ARC_sitePurposeExpansionEnabled", false' "$INIT" \
    || fail "ARC_sitePurposeExpansionEnabled missing or not defaulted false in initServer.sqf"
pass "expansion toggle present and defaults false"

# The templates file must actually consume the toggle to gate the expansion set.
grep -q 'ARC_sitePurposeExpansionEnabled' "$TPL" \
    || fail "site templates do not read ARC_sitePurposeExpansionEnabled — expansion is not gated"
grep -q '_expansionTemplates' "$TPL" \
    || fail "site templates do not declare an _expansionTemplates set"
grep -q '_baseTemplates' "$TPL" \
    || fail "site templates do not declare a _baseTemplates set"
pass "expansion is gated behind the toggle; base + expansion sets are separated"

# sqflint-compat: avoid known parser-compat pitfalls in the changed data file.
for badpat in 'findIf' 'isNotEqualTo' 'toUpperANSI' 'toLowerANSI'; do
    if grep -qE "\b$badpat\b" "$TPL"; then
        fail "sqflint-compat: $badpat used in site templates SQF"
    fi
done
pass "site templates SQF avoids known sqflint-compat pitfalls"

python3 - "$TPL" "$WORLD" "$PAT" <<'PY'
import re, sys
tpl_path, world_path, pat_path = sys.argv[1], sys.argv[2], sys.argv[3]
tpl = open(tpl_path, encoding='utf-8').read()
world = open(world_path, encoding='utf-8').read()
pat = open(pat_path, encoding='utf-8').read()

# --- Base set: the three original sites must remain unconditional. ---
base_m = re.search(r'_baseTemplates\s*=\s*\[', tpl)
exp_m = re.search(r'_expansionTemplates\s*=\s*\[', tpl)
if not base_m or not exp_m:
    raise SystemExit("could not locate _baseTemplates / _expansionTemplates blocks")
base_block = tpl[base_m.end():exp_m.start()]
for site in ("KarkanakPrison", "PresidentialPalace", "EmbassyCompound"):
    if site not in base_block:
        raise SystemExit("base template set is missing original site: %s" % site)

# --- Expansion set: extract the [siteId, marker, ...] header of each entry. ---
exp_block = tpl[exp_m.end():]
# Each site entry opens with: "SiteId", "ARC_loc_Marker", <trig>, <despawn>, ...
entries = re.findall(r'"([A-Za-z0-9_]+)",\s*"(ARC_loc_[A-Za-z0-9_]+)",\s*\d+', exp_block)
exp_ids = [sid for sid, mk in entries]
if not exp_ids:
    raise SystemExit("no expansion site entries parsed")
if len(set(exp_ids)) != len(exp_ids):
    dupes = sorted({i for i in exp_ids if exp_ids.count(i) > 1})
    raise SystemExit("duplicate expansion site ids: %s" % dupes)

# --- World export: valid named-location ids. ---
world_named_block = world.split("private _sites", 1)[0]
named_ids = set(re.findall(r'\["([A-Za-z0-9_]+)",\s*"', world_named_block))

# --- Spawn matrix: id -> purpose mapping. ---
m = re.search(r'\["locationPurposes",\s*\[', pat)
i = m.end() - 1
depth = 0
loc_section = None
for j in range(i, len(pat)):
    if pat[j] == '[':
        depth += 1
    elif pat[j] == ']':
        depth -= 1
        if depth == 0:
            loc_section = pat[i:j+1]
            break
loc_map = dict(re.findall(r'\["([A-Za-z0-9_]+)",\s*"([A-Z_]+)"\]', loc_section))

# Purposes that intentionally carry no baseline pop should NOT get a SitePop site.
for sid, marker in entries:
    if sid not in named_ids:
        raise SystemExit("expansion site '%s' is not a named location in the world export" % sid)
    if "ARC_loc_%s" % sid != marker:
        raise SystemExit("expansion site '%s' marker mismatch: %s" % (sid, marker))
    purpose = loc_map.get(sid)
    if purpose is None:
        raise SystemExit("expansion site '%s' has no purpose mapping in the matrix" % sid)
    if purpose == "NO_BASELINE_POP":
        raise SystemExit("expansion site '%s' is mapped NO_BASELINE_POP; it must not get a SitePop baseline" % sid)

print("[PASS] %d expansion sites parsed; all map to real named locations with a baseline purpose" % len(exp_ids))
print("[PASS] expansion markers follow the ARC_loc_<id> convention; no duplicates")
PY

pass "SitePop purpose-expansion contract is satisfied"
