#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -n "$pattern" "$file" >/dev/null; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

check "\[\"casreq_snapshot\", _snapshot\]" "functions/casreq/fn_casreqBroadcastDelta.sqf" "CASREQ bundle payload includes casreq_snapshot"
check "\[\"rev\", _rev\]" "functions/casreq/fn_casreqBroadcastDelta.sqf" "CASREQ bundle metadata includes rev"
check "\[\"updatedAt\", serverTime\]" "functions/casreq/fn_casreqBroadcastDelta.sqf" "CASREQ bundle metadata includes updatedAt"
check "\[\"actor\", _actor\]" "functions/casreq/fn_casreqBroadcastDelta.sqf" "CASREQ bundle metadata includes actor"
check "\[\"casreq\", _casreqPub\]" "functions/core/fn_publicBroadcastState.sqf" "Public state includes casreq block"
check "\[\"casreq_snapshot\", _casreqSnapshot\]" "functions/core/fn_publicBroadcastState.sqf" "Public casreq block includes full snapshot key"

# C1 — RAVEN JTAC → CASREQ 9-line prefill reuses the existing casreqOpen path
check "remoteExec \[\"ARC_fnc_casreqOpen\", 2\]" "functions/casreq/fn_casreqJtacPrefill.sqf" "JTAC prefill submits via existing ARC_fnc_casreqOpen RPC path"
check "line6_type_mark" "functions/casreq/fn_casreqJtacPrefill.sqf" "JTAC prefill seeds 9-line marking method"
check "line7_location_friendlies" "functions/casreq/fn_casreqJtacPrefill.sqf" "JTAC prefill seeds 9-line line-of-friendlies default"

if [[ "$pass" != true ]]; then
  exit 1
fi
