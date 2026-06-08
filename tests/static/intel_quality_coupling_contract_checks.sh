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

check 'ARC_fnc_intelQualityCouple' "functions/intel/fn_intelQualityCouple.sqf" "Intel quality coupling helper exists"
check 'if \(!isServer\) exitWith \{\[\]\}' "functions/intel/fn_intelQualityCouple.sqf" "Coupling helper is server guarded"
check 'W_EFF_U' "functions/intel/fn_intelQualityCouple.sqf" "Coupling reads CIVSUB WHITE effective score"
check 'R_EFF_U' "functions/intel/fn_intelQualityCouple.sqf" "Coupling reads CIVSUB RED effective score"
check 'G_EFF_U' "functions/intel/fn_intelQualityCouple.sqf" "Coupling reads CIVSUB GREEN effective score"
check 'threat_v0_district_risk' "functions/intel/fn_intelQualityCouple.sqf" "Coupling reads Threat risk state"
check 'quality_delta' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits quality delta"
check 'confidence_band' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits confidence band"
check 'timeliness' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits timeliness"
check 'precision' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits precision"
check 'trust' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits trust"
check 'intimidation' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits intimidation"
check 'stability' "functions/intel/fn_intelQualityCouple.sqf" "Coupling emits stability"

check 'ARC_fnc_intelLeadCreateCoupled' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator exists"
check 'if \(!isServer\) exitWith \{""\}' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator is server guarded"
check 'intel_quality_coupling' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator writes coupling metadata"
check 'intel_confidence_band' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator writes confidence metadata"
check 'intel_precision' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator writes precision metadata"
check 'intel_timeliness' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator writes timeliness metadata"
check '\] call ARC_fnc_leadCreate' "functions/intel/fn_intelLeadCreateCoupled.sqf" "Coupled lead creator preserves ARC_fnc_leadCreate path"

check 'ARC_fnc_intelLeadCreateCoupled' "functions/ied/fn_iedEmitLeads.sqf" "IED leads use coupled creator"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/ied/fn_vbiedEmitLeads.sqf" "VBIED leads use coupled creator"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/threat/fn_threatLeadEmitFromOutcome.sqf" "Suicide leads use coupled creator"
check 'ARC_fnc_intelLeadCreateCoupled' "functions/threat/fn_threatScheduleEvent.sqf" "Scheduled non-IED leads use coupled creator"

check 'class intelQualityCouple' "config/CfgFunctions.hpp" "CfgFunctions registers intelQualityCouple"
check 'class intelLeadCreateCoupled' "config/CfgFunctions.hpp" "CfgFunctions registers intelLeadCreateCoupled"

if [[ "$pass" != true ]]; then
  exit 1
fi
