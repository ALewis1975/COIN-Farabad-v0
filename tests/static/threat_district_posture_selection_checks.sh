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

check 'ARC_threatDistrictPostureSelectionEnabled' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler has posture-selection feature flag"
check 'DISTRICT_POSTURE_V1' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records posture-selection policy"
check 'W_EFF_U' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler reads CIVSUB WHITE effective score"
check 'R_EFF_U' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler reads CIVSUB RED effective score"
check 'G_EFF_U' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler reads CIVSUB GREEN effective score"
check 's_coop' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records cooperation score"
check 's_threat' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records threat score"
check 'posture_score' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records posture score"
check 'selected_tier' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records selected tier"
check 'tier_source' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records tier source"
check 'selection_inputs' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records explainable selection inputs"
check '_selectedTier,[[:space:]]*// tier' "functions/threat/fn_threatSchedulerTick.sqf" "Threat schedule event uses selected tier"

check 'ARC_threatDistrictPostureSelectionEnabled' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes posture-selection flag"
check 'posture_score_formula' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes posture formula"
check 'topPostureDistricts' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes top posture districts"
check 'posture_score_bands' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes posture bands"
check 'selection_inputs' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot exposes explainable district inputs"
check 'district_posture_selection_enabled' "functions/threat/fn_threatEconomySnapshotBuild.sqf" "Economy snapshot summary exposes selection state"

check 'ARC_fnc_intelQualityCouple' "functions/intel/fn_intelQualityCouple.sqf" "Intel quality coupling helper exists"
check 'trust' "functions/intel/fn_intelQualityCouple.sqf" "Coupling helper computes trust"
check 'intimidation' "functions/intel/fn_intelQualityCouple.sqf" "Coupling helper computes intimidation"
check 'stability' "functions/intel/fn_intelQualityCouple.sqf" "Coupling helper computes stability"
check 'confidence_band' "functions/intel/fn_intelQualityCouple.sqf" "Coupling helper emits confidence band"
check 'precision' "functions/intel/fn_intelQualityCouple.sqf" "Coupling helper emits precision band"
check 'intel_quality_coupling' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator writes coupling metadata"
check 'intel_confidence_band' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator writes confidence metadata"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/ied/fn_iedEmitLeads.sqf" "IED leads use coupled lead creation"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/ied/fn_vbiedEmitLeads.sqf" "VBIED leads use coupled lead creation"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/threat/fn_threatLeadEmitFromOutcome.sqf" "Suicide leads use coupled lead creation"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/threat/fn_threatScheduleEvent.sqf" "Scheduled non-IED leads use coupled lead creation"

if [[ "$pass" != true ]]; then
  exit 1
fi
