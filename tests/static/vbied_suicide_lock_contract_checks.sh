#!/usr/bin/env bash
# Static contract checks: VBIED / suicide-bomber subsystem lock (v1).
# Locks spawn pacing (tier gates, cooldowns, one-shot flags, fairness gates),
# detonation behavior (idempotence, EOD-approval gate, live-vehicle position),
# and lead-emission tuning (per-transition lead packages + detonation penalty)
# against docs/projectFiles/Farabad_IED_VBIED_Suicide_Subsystem_Planning.md.
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

# --- Pacing knobs: authoritative defaults in initServer ----------------------
check 'ARC_vbiedPhase3_enabled", true, true' initServer.sqf \
  "initServer seeds ARC_vbiedPhase3_enabled (replicated)"
check 'ARC_vbiedCooldownSeconds", 1800, true' initServer.sqf \
  "initServer seeds ARC_vbiedCooldownSeconds=1800 (rare-threat pacing)"
check 'ARC_vbiedDrivenEnabled", true, true' initServer.sqf \
  "initServer seeds ARC_vbiedDrivenEnabled (replicated)"
check 'ARC_suicideBomberEnabled", true, true' initServer.sqf \
  "initServer seeds ARC_suicideBomberEnabled (replicated)"
check 'ARC_vbiedDrivenIntelLevel", 0, true' initServer.sqf \
  "initServer seeds ARC_vbiedDrivenIntelLevel telegraph floor"
check 'ARC_vbiedDetonationCooldownS", 3600, true' initServer.sqf \
  "initServer seeds ARC_vbiedDetonationCooldownS=3600 (post-detonation district cooldown)"
check 'ARC_vbiedVehicleClassPool' initServer.sqf \
  "initServer owns the authoritative civilian VBIED vehicle class pool"

# Safe mode disables all three escalation spawn paths
check 'ARC_vbiedDrivenEnabled", false, true' initServer.sqf \
  "safe mode disables driven VBIED spawn path"
check 'ARC_suicideBomberEnabled", false, true' initServer.sqf \
  "safe mode disables suicide-bomber spawn path"

# Operator startup audit covers the locked knobs
check 'ARC_vbiedDrivenEnabled", "bool"' initServer.sqf \
  "operator audit catalog covers ARC_vbiedDrivenEnabled"
check 'ARC_suicideBomberEnabled", "bool"' initServer.sqf \
  "operator audit catalog covers ARC_suicideBomberEnabled"
check 'ARC_vbiedDetonationCooldownS", "number"' initServer.sqf \
  "operator audit catalog covers ARC_vbiedDetonationCooldownS"

# --- Pacing: escalation-tier gates (governor parity in execution layer) ------
check 'ESCALATION_TIER deny' functions/ied/fn_vbiedSpawnTick.sqf \
  "parked VBIED tick enforces tier gate (deny log)"
check '_tier < 2' functions/ied/fn_vbiedSpawnTick.sqf \
  "parked VBIED requires escalation tier >= 2"
check 'ESCALATION_TIER deny' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED tick enforces tier gate (deny log)"
check '_tier < 2' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED requires escalation tier >= 2"
check 'ESCALATION_TIER deny' functions/ied/fn_suicideBomberSpawnTick.sqf \
  "suicide-bomber tick enforces tier gate (deny log)"
check '_tier < 3' functions/ied/fn_suicideBomberSpawnTick.sqf \
  "suicide bomber requires escalation tier >= 3 (CRITICAL)"
check 'isEqualTo "VBIED")   then { _tierMin = 2; }' functions/threat/fn_threatGovernorCheck.sqf \
  "governor tier minimum for VBIED is 2"
check 'isEqualTo "SUICIDE") then { _tierMin = 3; }' functions/threat/fn_threatGovernorCheck.sqf \
  "governor tier minimum for SUICIDE is 3"

# --- Pacing: cooldown + one-shot governors ------------------------------------
check 'ARC_vbiedCooldownSeconds' functions/ied/fn_vbiedSpawnTick.sqf \
  "parked VBIED tick consumes rearm cooldown"
check 'ARC_vbiedDrivenSpawned' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED tick is one-shot per incident"
check 'ARC_suicideBomberSpawned' functions/ied/fn_suicideBomberSpawnTick.sqf \
  "suicide-bomber tick is one-shot per incident"
check 'ARC_vbiedDrivenSpawned", false, true' functions/core/fn_execInitActive.sqf \
  "execInitActive resets driven VBIED one-shot flag per incident"
check 'ARC_suicideBomberSpawned", false, true' functions/core/fn_execInitActive.sqf \
  "execInitActive resets suicide-bomber one-shot flag per incident"
check 'ARC_suicideBomberDetonated", false, true' functions/core/fn_execInitActive.sqf \
  "execInitActive resets suicide-bomber detonation flag per incident"

# --- Pacing: fairness / telegraphing gates ------------------------------------
check 'no players near spawn' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED aborts (EXPIRED) when no players near spawn"
check '"STAGED", "driven_vbied_staged"' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED emits STAGED transition before spawning"
check 'ARC_vbiedDrivenIntelLevel' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED forces minimum warning lead at intel level 0"
check 'no players near approach' functions/ied/fn_suicideBomberSpawnTick.sqf \
  "suicide bomber aborts (EXPIRED) when no players near approach path"
check '"STAGED", "sb_approach_staged"' functions/ied/fn_suicideBomberSpawnTick.sqf \
  "suicide bomber emits STAGED transition on spawn"

# Driven VBIED uses the civilian vehicle pool, not military placeholders
check 'ARC_vbiedVehicleClassPool' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED draws vehicle from civilian class pool"
check_absent 'O_MRAP_02_F' functions/ied/fn_vbiedDrivenSpawnTick.sqf \
  "driven VBIED no longer hardcodes military MRAP placeholder"

# --- Detonation behavior --------------------------------------------------------
check 'activeVbiedDetonated' functions/ied/fn_vbiedServerDetonate.sqf \
  "VBIED detonation is idempotent (state guard)"
check 'activeVbiedSafe' functions/ied/fn_vbiedServerDetonate.sqf \
  "rendered-safe VBIED never detonates"
check 'VBIED_DETONATE_DENIED' functions/ied/fn_vbiedServerDetonate.sqf \
  "client-driven detonation requires TOC EOD approval (denied path logged)"
check 'ARC_vbiedDrivenNetId' functions/ied/fn_vbiedServerDetonate.sqf \
  "detonation resolves live driven-vehicle position"
check 'activeVbiedVehicleNetId' functions/ied/fn_vbiedServerDetonate.sqf \
  "detonation resolves live parked-vehicle position"
check 'ARC_fnc_iedHandleDetonation' functions/ied/fn_vbiedServerDetonate.sqf \
  "VBIED detonation delegates to shared detonation pipeline"
check 'ARC_suicideBomberDetonated' functions/ied/fn_suicideBomberOnDetonate.sqf \
  "suicide-bomber detonation is idempotent (dedupe flag)"
check '"DETONATED", "suicide_bomber_detonated"' functions/ied/fn_suicideBomberOnDetonate.sqf \
  "suicide-bomber detonation transitions threat record to DETONATED"
check 'ARC_fnc_vbiedServerOnDestroyed' functions/ied/fn_vbiedSpawnTick.sqf \
  "parked VBIED registers Killed EH for non-detonation destruction outcomes"

# RemoteExec allowlist (server-targeted only)
check 'ARC_fnc_vbiedServerDetonate           { allowedTargets = 2; }' config/CfgRemoteExec.hpp \
  "vbiedServerDetonate allowlisted server-only"
check 'ARC_fnc_suicideBomberOnDetonate       { allowedTargets = 2; }' config/CfgRemoteExec.hpp \
  "suicideBomberOnDetonate allowlisted server-only"

# --- Lead emission tuning -------------------------------------------------------
check 'case "VBIED": { \[_rec, _transition\] call ARC_fnc_vbiedEmitLeads }' functions/threat/fn_threatLeadEmitFromOutcome.sqf \
  "lead router dispatches VBIED family to ARC_fnc_vbiedEmitLeads"
check '"vbied_watch"' functions/ied/fn_vbiedEmitLeads.sqf \
  "STAGED emits VBIED Watch lead"
check '"checkpoint_advisory"' functions/ied/fn_vbiedEmitLeads.sqf \
  "STAGED emits Checkpoint Advisory lead"
check '"vehicle_origin_lead"' functions/ied/fn_vbiedEmitLeads.sqf \
  "DISCOVERED emits Vehicle Origin lead"
check '"urban_support_lead"' functions/ied/fn_vbiedEmitLeads.sqf \
  "DISCOVERED emits Urban Support lead"
check '"facilitator_node_lead"' functions/ied/fn_vbiedEmitLeads.sqf \
  "INTERDICTED emits Facilitator Node lead"
check '"vbied_cell_attribution"' functions/ied/fn_vbiedEmitLeads.sqf \
  "INTERDICTED emits VBIED cell attribution lead"
check '"network_escalation_lead"' functions/ied/fn_vbiedEmitLeads.sqf \
  "DETONATED emits Network Escalation lead"
check '"copycat_risk_lead"' functions/ied/fn_vbiedEmitLeads.sqf \
  "DETONATED emits Copycat Risk lead"
check 'ARC_vbiedDetonationCooldownS' functions/ied/fn_vbiedEmitLeads.sqf \
  "DETONATED applies district risk cooldown penalty"
check '"retaliation_risk"\|retaliation_risk' functions/threat/fn_threatLeadEmitFromOutcome.sqf \
  "SUICIDE DETONATED emits Retaliation Risk lead"
check 'recruitment_pressure' functions/threat/fn_threatLeadEmitFromOutcome.sqf \
  "SUICIDE DETONATED emits Recruitment Pressure lead"
check 'sb_threat_advisory' functions/threat/fn_threatLeadEmitFromOutcome.sqf \
  "SUICIDE STAGED emits Suicide Threat Advisory lead"

# --- Runtime wiring ------------------------------------------------------------
check 'ARC_fnc_vbiedSpawnTick;' functions/core/fn_execTickActive.sqf \
  "execTickActive wires parked VBIED tick"
check 'ARC_fnc_vbiedDrivenSpawnTick;' functions/core/fn_execTickActive.sqf \
  "execTickActive wires driven VBIED tick"
check 'ARC_fnc_suicideBomberSpawnTick;' functions/core/fn_execTickActive.sqf \
  "execTickActive wires suicide-bomber tick"
check 'class vbiedSpawnTick' config/CfgFunctions.hpp \
  "vbiedSpawnTick registered in CfgFunctions"
check 'class vbiedDrivenSpawnTick' config/CfgFunctions.hpp \
  "vbiedDrivenSpawnTick registered in CfgFunctions"
check 'class vbiedServerDetonate' config/CfgFunctions.hpp \
  "vbiedServerDetonate registered in CfgFunctions"
check 'class vbiedEmitLeads' config/CfgFunctions.hpp \
  "vbiedEmitLeads registered in CfgFunctions"
check 'class suicideBomberSpawnTick' config/CfgFunctions.hpp \
  "suicideBomberSpawnTick registered in CfgFunctions"
check 'class suicideBomberOnDetonate' config/CfgFunctions.hpp \
  "suicideBomberOnDetonate registered in CfgFunctions"

if $pass; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
