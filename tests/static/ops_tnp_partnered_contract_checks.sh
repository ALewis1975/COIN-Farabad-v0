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

check_absent() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -n "$pattern" "$file" >/dev/null; then
    echo "[FAIL] $label"
    pass=false
  else
    echo "[PASS] $label"
  fi
}

REQ="functions/ops/fn_opsTnpPartneredRequest.sqf"

# C3 — TNP partnered ops request reuses the existing TOC queue intake (no new handler).
check "remoteExec \[\"ARC_fnc_intelQueueSubmit\", 2\]" "$REQ" "TNP partnered request submits via existing ARC_fnc_intelQueueSubmit RPC path"
check "\"LEAD_REQUEST\"" "$REQ" "TNP partnered request submits a LEAD_REQUEST kind"
check "\[\"leadType\", _leadType\]" "$REQ" "TNP partnered request payload includes leadType"
check "\[\"confidence\", _conf\]" "$REQ" "TNP partnered request payload includes confidence"
check "\[\"tag\", \"TNP_PARTNERED\"\]" "$REQ" "TNP partnered request tags the lead request TNP_PARTNERED"
check "\[\"source\", \"TNP_PARTNERED\"\]" "$REQ" "TNP partnered request stamps source meta TNP_PARTNERED"
check "\[\"confidence\", _conf\]" "$REQ" "TNP partnered request stamps confidence meta"
check "ARC_opsTnpPartneredRequestEnabled" "$REQ" "TNP partnered request honours the feature flag"
check "ARC_fnc_rolesHasGroupIdToken" "$REQ" "TNP partnered request gates on the TNP callsign token"

# Doctrine: leads route through the TOC queue — the action must NOT create tasks
# or call leadCreate / tocBacklogEnqueue directly from the client.
check_absent "call ARC_fnc_leadCreate" "$REQ" "TNP partnered request does not create leads directly"
check_absent "call ARC_fnc_tocBacklogEnqueue" "$REQ" "TNP partnered request does not enqueue the TOC backlog directly"
check_absent "ARC_fnc_rpcValidateSender" "$REQ" "TNP partnered request adds no new server validation handler"

# Wiring: flag seeded server-side and action registered.
check "ARC_opsTnpPartneredRequestEnabled" "initServer.sqf" "ARC_opsTnpPartneredRequestEnabled seeded in initServer"
check "ARC_fnc_opsTnpPartneredRequest" "functions/core/fn_tocInitPlayer.sqf" "TNP partnered request wired as a player addAction"
check "class opsTnpPartneredRequest" "config/CfgFunctions.hpp" "opsTnpPartneredRequest registered in CfgFunctions"

# Consumer: the TNP_PARTNERED lead tag is carried onto the active incident and
# forces host-nation local support to spawn regardless of incident type.
LS="functions/ops/fn_opsSpawnLocalSupport.sqf"
check "activeLeadTag" "$LS" "Local-support spawn reads the active incident lead tag"
check "TNP_PARTNERED" "$LS" "Local-support spawn recognises the TNP_PARTNERED lead tag"
check "_isTnpPartnered" "$LS" "Local-support spawn forces eligibility for TNP_PARTNERED leads"

# CIVSUB effects: partnered leads must change district deltas and leave an OPS-log audit trail.
CIV="functions/civsub/fn_civsubApplyIncidentOutcomeDelta.sqf"
check "activeLeadTag" "$CIV" "CIVSUB outcome reads active lead tag"
check "TNP_PARTNERED" "$CIV" "CIVSUB outcome recognises TNP_PARTNERED tag"
check "activeIncidentTnpPartneredCivsubEffect" "$CIV" "CIVSUB outcome stores partnered effect read model"
check "TNP_PARTNERED_CIVSUB_EFFECT" "$CIV" "CIVSUB outcome logs partnered district effect"

# Prompts: selections use two-button guiMessage choices (reliably captured), and
# the dead free-text/parseNumber override pattern is gone.
check "TNP Partnered Ops — Task" "$REQ" "Partnered task type captured via a two-button choice"
check "TNP Partnered Ops — Urgency" "$REQ" "Urgency captured via a two-button choice"
check_absent "parseNumber" "$REQ" "No illusory free-text priority parse remains"
check_absent "isEqualType \"\") then" "$REQ" "No illusory guiMessage free-text capture remains"

if [[ "$pass" != true ]]; then
  exit 1
fi
