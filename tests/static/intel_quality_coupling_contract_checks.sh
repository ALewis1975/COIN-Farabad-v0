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

check 'ARC_fnc_intelQualityCoupleDistrict' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Intel quality coupling helper exists"
check 'trust_score' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Helper emits trust score"
check 'intimidation_score' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Helper emits intimidation score"
check 'stability_score' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Helper emits stability score"
check 'quality_band' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Helper emits quality band"
check 'precision' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Helper emits precision label"
check 'timeliness' "functions/intel/fn_intelQualityCoupleDistrict.sqf" "Helper emits timeliness label"

check 'ARC_fnc_intelQualityCoupleDistrict' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler calls quality coupling helper"
check 'base_intel_quality' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records base intel quality"
check 'coupled_intel_quality' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records coupled intel quality"
check 'intel_quality_meta' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler records intel quality metadata"
check '_intelQualityMeta' "functions/threat/fn_threatSchedulerTick.sqf" "Scheduler passes quality metadata to threat schedule event"

check '_intelQualityMeta' "functions/threat/fn_threatScheduleEvent.sqf" "Threat record schedule event accepts quality metadata"
check 'intel_quality_meta' "functions/threat/fn_threatScheduleEvent.sqf" "Threat record stores quality metadata"
check 'quality_band' "functions/threat/fn_threatScheduleEvent.sqf" "Threat record stores quality band"
check 'quality_coupling' "functions/threat/fn_threatScheduleEvent.sqf" "Non-IED leads carry quality coupling metadata"

check 'quality_coupling' "functions/ied/fn_iedEmitLeads.sqf" "IED leads carry quality coupling metadata"
check 'intel_quality_meta' "functions/ied/fn_iedEmitLeads.sqf" "IED leads carry quality metadata"
check '_leadStrength' "functions/ied/fn_iedEmitLeads.sqf" "IED leads use coupled lead-strength helper"

check 'quality_coupling' "functions/ied/fn_vbiedEmitLeads.sqf" "VBIED leads carry quality coupling metadata"
check 'intel_quality_meta' "functions/ied/fn_vbiedEmitLeads.sqf" "VBIED leads carry quality metadata"
check '_leadStrength' "functions/ied/fn_vbiedEmitLeads.sqf" "VBIED leads use coupled lead-strength helper"

check 'quality_coupling' "functions/threat/fn_threatLeadEmitFromOutcome.sqf" "Suicide leads carry quality coupling metadata"
check 'intel_quality_meta' "functions/threat/fn_threatLeadEmitFromOutcome.sqf" "Suicide leads carry quality metadata"
check '_leadStrength' "functions/threat/fn_threatLeadEmitFromOutcome.sqf" "Suicide leads use coupled lead-strength helper"

if [[ "$pass" != true ]]; then
  exit 1
fi
