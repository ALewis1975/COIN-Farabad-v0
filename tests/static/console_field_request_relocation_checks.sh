#!/usr/bin/env bash
set -euo pipefail

# Contract: the JTAC CAS prefill, SHADOW ISR lead bridge and TNP partnered-ops
# field requests are surfaced from the Farabad Console (S2/INTEL tab) instead of
# the player action menu. The underlying client functions, feature flags and
# server RPC paths are unchanged; only the trigger surface moved.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -nE "$pattern" "$file" >/dev/null; then
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
  if grep -nE "$pattern" "$file" >/dev/null; then
    echo "[FAIL] $label"
    pass=false
  else
    echo "[PASS] $label"
  fi
}

TOC="functions/core/fn_tocInitPlayer.sqf"
PAINT="functions/ui/fn_uiConsoleIntelPaint.sqf"
CLICK="functions/ui/fn_uiConsoleClickPrimary.sqf"
ONLOAD="functions/ui/fn_uiConsoleOnLoad.sqf"

# (a) The three player addActions (and their per-player guard flags) are gone.
check_absent "ARC_casreqJtacPrefillActionAdded" "$TOC" "JTAC CAS prefill addAction removed from player init"
check_absent "ARC_isrShadowLeadBridgeActionAdded" "$TOC" "SHADOW ISR bridge addAction removed from player init"
check_absent "ARC_opsTnpPartneredRequestActionAdded" "$TOC" "TNP partnered request addAction removed from player init"

# (b) Console surfaces the three rows under FIELD REQUESTS, each flag + role gated.
check "FIELD REQUESTS" "$PAINT" "Console INTEL tab paints a FIELD REQUESTS section"
check "FIELD_JTAC_CAS" "$PAINT" "Console surfaces the JTAC CAS prefill row"
check "FIELD_SHADOW_ISR" "$PAINT" "Console surfaces the SHADOW ISR bridge row"
check "FIELD_TNP_PARTNERED" "$PAINT" "Console surfaces the TNP partnered-ops row"
check "ARC_casreqJtacPrefillEnabled" "$PAINT" "JTAC row honours its feature flag"
check "ARC_isrShadowLeadBridgeEnabled" "$PAINT" "SHADOW row honours its feature flag"
check "ARC_opsTnpPartneredRequestEnabled" "$PAINT" "TNP row honours its feature flag"
check "_isShadowTok += .*\"SHADOW\".*rolesHasGroupIdToken" "$PAINT" "SHADOW row derives gating from the SHADOW callsign token"
check "_isTnpTok += .*\"TNP\".*rolesHasGroupIdToken" "$PAINT" "TNP row derives gating from the TNP callsign token"
check "_canFieldShadow = _flagShadow" "$PAINT" "SHADOW row combines its flag with the SHADOW/S2/Command gate"
check "_canFieldTnp += _flagTnp" "$PAINT" "TNP row combines its flag with the TNP/S3/Command gate"

# (c) Primary click handler routes each row: close the console, then spawn the
#     unchanged client function (so the in-world marking context is valid).
check "FIELD_JTAC_CAS" "$CLICK" "Primary handler routes the JTAC row"
check "FIELD_SHADOW_ISR" "$CLICK" "Primary handler routes the SHADOW row"
check "FIELD_TNP_PARTNERED" "$CLICK" "Primary handler routes the TNP row"
check "closeDialog 0" "$CLICK" "Primary handler closes the console before running a field request"
check "spawn ARC_fnc_casreqJtacPrefill" "$CLICK" "Primary handler spawns the unchanged JTAC CAS prefill"
check "spawn ARC_fnc_intelShadowLeadBridge" "$CLICK" "Primary handler spawns the unchanged SHADOW ISR bridge"
check "spawn ARC_fnc_opsTnpPartneredRequest" "$CLICK" "Primary handler spawns the unchanged TNP partnered request"

# (d) INTEL tab reachable by the relocated operators (SHADOW/TNP/queue approver).
check "\\[player, \"SHADOW\"\\] call ARC_fnc_rolesHasGroupIdToken" "$ONLOAD" "INTEL tab visibility checks SHADOW callsign token"
check "\\[player, \"TNP\"\\] call ARC_fnc_rolesHasGroupIdToken" "$ONLOAD" "INTEL tab visibility checks TNP callsign token"
check "call ARC_fnc_rolesCanApproveQueue" "$ONLOAD" "INTEL tab visibility checks queue-approver role"
check "_canIntel = _canIntel \\\|\\\| _isShadowTok \\\|\\\| _isTnpTok \\\|\\\| _canApprove" "$ONLOAD" "INTEL tab visibility extended for relocated field-request operators"

# (e) No new server RPC / validation handler introduced by the relocation.
check_absent "ARC_fnc_rpcValidateSender" "$CLICK" "Console routing adds no new server validation handler"

if [[ "$pass" != true ]]; then
  echo "Console field-request relocation contract checks FAILED."
  exit 1
fi
echo "Console field-request relocation contract checks passed."
