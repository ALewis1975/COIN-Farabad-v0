#!/usr/bin/env bash
# Static contract checks: complex/chain IED reachability (un-deferred modules).
# Asserts the tier-gated wiring of ARC_fnc_iedChainEmplace / ARC_fnc_iedComplexAttackStage
# into the active incident runtime, the shared idempotent chain detonation path,
# and the deferred-cleanup coverage for secondary entities.
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

# --- Feature flags -----------------------------------------------------------
check 'ARC_iedChainEnabled", true, true' initServer.sqf \
  "initServer seeds ARC_iedChainEnabled (replicated)"
check 'ARC_iedComplexAttackEnabled", true, true' initServer.sqf \
  "initServer seeds ARC_iedComplexAttackEnabled (replicated)"

# --- CfgFunctions registration -------------------------------------------------
check 'class iedChainEmplace' config/CfgFunctions.hpp \
  "iedChainEmplace registered in CfgFunctions"
check 'class iedChainDetonate' config/CfgFunctions.hpp \
  "iedChainDetonate registered in CfgFunctions"
check 'class iedComplexAttackStage' config/CfgFunctions.hpp \
  "iedComplexAttackStage registered in CfgFunctions"

# --- Tier-derived execution profile (AO activation) ---------------------------
check '"execution", _execProf' functions/threat/fn_threatOnAOActivated.sqf \
  "threatOnAOActivated writes execution profile onto threat record"
check '"chain_count", _chainCount' functions/threat/fn_threatOnAOActivated.sqf \
  "execution profile includes chain_count"
check '"hasSecondaryAttack", _hasSecondary' functions/threat/fn_threatOnAOActivated.sqf \
  "execution profile includes hasSecondaryAttack"
check '"complexity", _complexity' functions/threat/fn_threatOnAOActivated.sqf \
  "execution profile includes complexity"
check '_tier >= 2.*_chainCount = 1\|if (_tier >= 2) then { _chainCount = 1; }' functions/threat/fn_threatOnAOActivated.sqf \
  "chain devices gated at tier >= 2"
check '_hasSecondary = (_tier >= 3)' functions/threat/fn_threatOnAOActivated.sqf \
  "secondary attack gated at tier >= 3"

# --- Spawn-tick reachability ---------------------------------------------------
check 'ARC_iedChainEnabled' functions/ied/fn_iedSpawnTick.sqf \
  "iedSpawnTick gates chain emplacement on ARC_iedChainEnabled"
check 'ARC_fnc_iedChainEmplace' functions/ied/fn_iedSpawnTick.sqf \
  "iedSpawnTick calls ARC_fnc_iedChainEmplace"
check 'ARC_iedComplexAttackEnabled' functions/ied/fn_iedSpawnTick.sqf \
  "iedSpawnTick gates complex staging on ARC_iedComplexAttackEnabled"
check 'ARC_fnc_iedComplexAttackStage' functions/ied/fn_iedSpawnTick.sqf \
  "iedSpawnTick calls ARC_fnc_iedComplexAttackStage"
check 'ARC_chainEmplaced' functions/ied/fn_iedSpawnTick.sqf \
  "chain emplacement is once-per-device guarded"
check 'ARC_complexAtkStaged_' functions/ied/fn_iedSpawnTick.sqf \
  "complex staging is once-per-threat guarded"

# --- Chain detonation (shared idempotent path) ---------------------------------
check 'if (!isServer) exitWith {false};' functions/ied/fn_iedChainDetonate.sqf \
  "iedChainDetonate is server-only"
check 'ARC_iedChainDetonatedPrimaries' functions/ied/fn_iedChainDetonate.sqf \
  "iedChainDetonate is idempotent per primary device"
check 'ARC_fnc_iedChainDetonate' functions/ied/fn_iedChainEmplace.sqf \
  "chainEmplace Killed EH delegates to shared iedChainDetonate"
check 'ARC_fnc_iedChainDetonate' functions/ied/fn_iedServerDetonate.sqf \
  "iedServerDetonate starts the chain sequence explicitly"
check 'ARC_complexAtkGroup_' functions/ied/fn_iedServerDetonate.sqf \
  "iedServerDetonate activates the staged ambush group"

# --- Complex attack staging hardening ------------------------------------------
check 'ARC_fnc_threatIsProtectedSpawnPos' functions/ied/fn_iedComplexAttackStage.sqf \
  "complexAttackStage respects protected spawn zones"
check 'ARC_opforPatrolUnitClasses' functions/ied/fn_iedComplexAttackStage.sqf \
  "complexAttackStage resolves OPFOR pool from mission config"
check 'ARC_fnc_cfgClassExists' functions/ied/fn_iedComplexAttackStage.sqf \
  "complexAttackStage validates unit classes via cfgClassExists"
check '_complexity < 3' functions/ied/fn_iedComplexAttackStage.sqf \
  "complexAttackStage keeps complexity >= 3 gate"

# --- Cleanup coverage ------------------------------------------------------------
check 'ARC_activeIedChainNetIds' functions/ied/fn_iedChainEmplace.sqf \
  "chainEmplace publishes chain netIds for cleanup"
check 'ARC_activeIedChainNetIds' functions/core/fn_execCleanupActive.sqf \
  "execCleanupActive cleans chain devices"
check 'iedComplexAtk' functions/core/fn_execCleanupActive.sqf \
  "execCleanupActive cleans complex ambush group"
check 'ARC_complexAtkStaged_' functions/core/fn_execCleanupActive.sqf \
  "execCleanupActive clears complex staging guard"

# --- Deferred framing removed -----------------------------------------------------
check_absent 'Deferred module' functions/ied/fn_iedChainEmplace.sqf \
  "chainEmplace no longer carries deferred-module framing"
check_absent 'Deferred module' functions/ied/fn_iedComplexAttackStage.sqf \
  "complexAttackStage no longer carries deferred-module framing"

# --- select-precedence regression guard --------------------------------------------
check_absent 'select 0 + _dist' functions/ied/fn_iedChainEmplace.sqf \
  "chainEmplace select-precedence bug fixed"
check_absent 'select 0 + _dist' functions/ied/fn_iedComplexAttackStage.sqf \
  "complexAttackStage select-precedence bug fixed"

echo
if $pass; then
  echo "ied_complex_chain_contract_checks: ALL CHECKS PASSED"
else
  echo "ied_complex_chain_contract_checks: FAILURES DETECTED"
  exit 1
fi
