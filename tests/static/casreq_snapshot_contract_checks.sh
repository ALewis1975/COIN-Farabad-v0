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

if [[ "$pass" != true ]]; then
  exit 1
fi
