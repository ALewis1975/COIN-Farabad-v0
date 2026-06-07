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

UP="functions/dossier/fn_dossierUpsertFromHandoff.sqf"
ANNEX="functions/dossier/fn_dossierAnnexBuild.sqf"
HANDOFF="functions/civsub/fn_civsubInteractHandoffSheriff.sqf"
SITREP="functions/core/fn_tocReceiveSitrep.sqf"

# B1 — SHERIFF handoff must produce a stable dossier id that survives delayed EPW flow.
check "private _dossierId = .*ARC_fnc_dossierUpsertFromHandoff" "$HANDOFF" "handoff captures dossier id returned by upsert"
check "_rec set \[\"dossier_id\", _dossierId\]" "$HANDOFF" "handoff stores stable dossier id on CIVSUB identity"
check "ARC_dossier_id" "$UP" "dossier upsert binds stable dossier id to detainee object"
check "ARC_dossier_handoff_task_id" "$UP" "dossier upsert binds handoff task id to detainee object"

# Runtime validation: persisted annex rebuild must guard mixed evidence payloads.
check "item_count" "$ANNEX" "dossier annex reads evidence item count"
check "_cnt isEqualType 0" "$ANNEX" "dossier annex validates evidence item count before adding"

# SITREP integration: annex is built from active task/district and stored separately.
check "activeIncidentSitrepAnnexDossier" "$SITREP" "SITREP stores SHERIFF dossier annex read model"
check "ARC_fnc_dossierAnnexBuild" "$SITREP" "SITREP builds SHERIFF dossier annex"

if [[ "$pass" != true ]]; then
  exit 1
fi

