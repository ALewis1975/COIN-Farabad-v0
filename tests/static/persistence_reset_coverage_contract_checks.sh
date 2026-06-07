#!/usr/bin/env bash
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

check_absent() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -Eq "$pattern" "$file"; then
    echo "[FAIL] $label"
    pass=false
  else
    echo "[PASS] $label"
  fi
}

check 'missionNamespace setVariable \["ARC_state", \+_resetDefaults\]' \
  functions/core/fn_resetAll.sqf \
  "resetAll replaces ARC_state with current stateInit defaults"

check '\["airbase_v1_records", \[\]\] call ARC_fnc_stateSet' \
  functions/core/fn_resetAll.sqf \
  "resetAll explicitly clears AIRBASE records"

check '\["airbase_v1_queue", \[\]\] call ARC_fnc_stateSet' \
  functions/core/fn_resetAll.sqf \
  "resetAll explicitly clears AIRBASE queue"

check '\["casreq_v1_records", createHashMap\] call ARC_fnc_stateSet' \
  functions/core/fn_resetAll.sqf \
  "resetAll explicitly clears CASREQ records"

check 'missionNamespace setVariable \["ARC_pub_casreqBundle", \[\], true\]' \
  functions/core/fn_resetAll.sqf \
  "resetAll clears public CASREQ bundle for JIP"

check_absent '\["airbase_v1_records", \[\]\] call ARC_fnc_stateSet;' \
  functions/ambiance/fn_airbaseInit.sqf \
  "airbaseInit does not wipe AIRBASE records on normal init"

check_absent '\["airbase_v1_queue", \[\]\] call ARC_fnc_stateSet;' \
  functions/ambiance/fn_airbaseInit.sqf \
  "airbaseInit does not wipe AIRBASE queue on normal init"

python3 - <<'PY'
import pathlib
import re
import sys

root = pathlib.Path('.')
state_lines = (root / 'functions/core/fn_stateInit.sqf').read_text().splitlines()
doc = (root / 'docs/architecture/Persistence_Reset_Coverage.md').read_text()

missing = []
for line in state_lines:
    match = re.match(r'([ \t]*)\["([^"]+)"\s*,', line)
    if not match:
        continue
    indent = len(match.group(1).replace('\t', '    '))
    if indent > 4:
        continue
    key = match.group(2)
    if f'`{key}`' not in doc:
        missing.append(key)

if missing:
    print('[FAIL] persistence coverage doc missing keys: ' + ', '.join(missing))
    sys.exit(1)

print('[PASS] persistence coverage doc lists every top-level stateInit key')
PY

if [[ "$pass" != true ]]; then
  exit 1
fi
