#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1" >&2; exit 1; }
require_grep() {
  local pattern="$1"
  local file="$2"
  local msg="$3"
  grep -Eq "$pattern" "$file" && pass "$msg" || fail "$msg"
}

require_grep 'class casreqAirbaseAvailability' config/CfgFunctions.hpp "CASREQ airbase availability function is registered"
require_grep 'ARC_fnc_casreqAirbaseAvailability' functions/casreq/fn_casreqDecide.sqf "CASREQ approval checks AIRBASESUB availability"
require_grep 'approval blocked by AIRBASESUB availability' functions/casreq/fn_casreqDecide.sqf "CASREQ approval has operator-facing AIRBASESUB block"
require_grep 'ARC_fnc_casreqAirbaseAvailability' functions/casreq/fn_casreqExecute.sqf "CASREQ execute re-checks AIRBASESUB availability"
require_grep 'airbase_availability' functions/core/fn_publicBroadcastState.sqf "Public CASREQ snapshot surfaces AIRBASESUB availability"

require_grep 'civsub_v1_rumor_enabled' functions/civsub/fn_civsubSchedulerTick.sqf "CIVSUB scheduler gates rumor loop"
require_grep 'cooldown_nextRumor_ts' functions/civsub/fn_civsubSchedulerTick.sqf "CIVSUB rumor loop is cooldown-bounded"
require_grep 'ARC_fnc_tocBacklogEnqueue' functions/civsub/fn_civsubSchedulerTick.sqf "CIVSUB leads enqueue into TOC backlog"
require_grep 'Rumor / informant lead' functions/civsub/fn_civsubSchedulerTick.sqf "CIVSUB rumor lead note identifies source"
require_grep '\["emit", true\]' functions/civsub/fn_civsubSchedulerEmitRumor.sqf "CIVSUB rumor emission creates a lead payload"

require_grep 'class baseServicesInit' config/CfgFunctions.hpp "Base services init function is registered"
require_grep 'class baseServicesSnapshot' config/CfgFunctions.hpp "Base services snapshot function is registered"
require_grep 'baseServices_v1_snapshot' functions/core/fn_stateInit.sqf "Base services state is schema-seeded"
require_grep 'ARC_fnc_baseServicesInit' functions/core/fn_bootstrapServer.sqf "Base services initialize during server bootstrap"
require_grep 'sustainmentDrainMult' functions/logistics/fn_supplyApplyAmbientDrain.sqf "Base services affect sustainment drain"
require_grep 'base_med_effective' functions/medical/fn_medicalSnapshot.sqf "Base services affect medical readiness"
require_grep 'base_services' functions/core/fn_sitrepSupplyBuildAnnex.sqf "SITREPs include base services snapshot"
require_grep 'command_risk' functions/core/fn_sitrepSupplyAssessMettTc.sqf "SITREP command decision includes base service risk"
require_grep 'Base Services' functions/ui/fn_uiConsoleDashboardPaint.sqf "HQ dashboard displays base services"

echo "[PASS] Lane C contract checks complete"
