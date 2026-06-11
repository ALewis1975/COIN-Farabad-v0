#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -q "$pattern" "$file"; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

# --- Spawn idempotency guardrails ---
check 'class threatIedSpawnRequest {}' "config/CfgFunctions.hpp" \
  "CfgFunctions registers threatIedSpawnRequest"

check 'SPTOKEN:' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request derives deterministic SPTOKEN"

check '"spawn_token"' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request writes spawn_token to world record"

check '"spawn_intent_ts"' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request writes spawn_intent_ts for restart rehydration"

check '"spawn_attempt_count"' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request tracks spawn_attempt_count"

check 'DENY_DUPLICATE_SPAWN' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request emits DENY_DUPLICATE_SPAWN on duplicate active manifestation"

check 'THREAT_SPAWN_DENIED' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request emits THREAT_SPAWN_DENIED event"

check 'ARC_fnc_threatEmitEvent' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request denial uses structured event emission"

check 'if (!isServer) exitWith' "functions/threat/fn_threatIedSpawnRequest.sqf" \
  "Spawn request is server-only"

# --- AO activated hook uses spawn idempotency ---
check 'ARC_fnc_threatIedSpawnRequest' "functions/threat/fn_threatOnAOActivated.sqf" \
  "AO activated hook calls spawn idempotency request"

check '"spawned_at"' "functions/threat/fn_threatOnAOActivated.sqf" \
  "AO activated hook writes spawned_at timestamp"

check '"ARC_threatSpawnToken"' "functions/threat/fn_threatOnAOActivated.sqf" \
  "AO activated hook tags object with spawn token"

check '_spawnGranted' "functions/threat/fn_threatOnAOActivated.sqf" \
  "AO activated hook gates object linking on spawn grant"

# --- Cleanup sync ---
check 'class threatIedCleanupSync {}' "config/CfgFunctions.hpp" \
  "CfgFunctions registers threatIedCleanupSync"

check '"cleanup_completed"' "functions/threat/fn_threatIedCleanupSync.sqf" \
  "Cleanup sync writes cleanup_completed marker"

check '"cleanup_ts"' "functions/threat/fn_threatIedCleanupSync.sqf" \
  "Cleanup sync writes cleanup_ts timestamp"

check 'THREAT_CLEANUP_STALE' "functions/threat/fn_threatIedCleanupSync.sqf" \
  "Cleanup sync emits THREAT_CLEANUP_STALE on repeat call"

check 'if (!isServer) exitWith' "functions/threat/fn_threatIedCleanupSync.sqf" \
  "Cleanup sync is server-only"

# --- Active threat linkage + detonation outcomes ---
check 'activeIedThreatId' "functions/threat/fn_threatOnAOActivated.sqf" \
  "AO activated hook writes canonical activeIedThreatId"

check 'ARC_activeIedThreatId' "functions/threat/fn_threatOnAOActivated.sqf" \
  "AO activated hook publishes active IED threat ID mirror"

check '"DETONATED"' "functions/core/fn_iedHandleDetonation.sqf" \
  "IED detonation handler drives Threat lifecycle to DETONATED"

check 'ARC_fnc_threatUpdateState' "functions/core/fn_iedHandleDetonation.sqf" \
  "IED detonation handler calls threatUpdateState"

# --- EOD disposition lifecycle RPC ---
check 'class iedServerRequestDisposition {}' "config/CfgFunctions.hpp" \
  "CfgFunctions registers iedServerRequestDisposition"

check 'class ARC_fnc_iedServerRequestDisposition' "config/CfgRemoteExec.hpp" \
  "CfgRemoteExec allowlists iedServerRequestDisposition to server"

check 'activeIedEvidenceRtbRequested' "functions/ied/fn_iedServerRequestDisposition.sqf" \
  "RTB_IED request records server-side lifecycle flag"

check 'activeVbiedTowRequested' "functions/ied/fn_iedServerRequestDisposition.sqf" \
  "TOW_VBIED request records server-side lifecycle flag"

check 'ARC_fnc_iedServerCheckDisposal' "functions/ied/fn_iedServerRequestDisposition.sqf" \
  "RTB_IED request invokes disposal-site logistics check"

check 'sender-owner/group mismatch' "functions/ied/fn_iedServerRequestDisposition.sqf" \
  "Disposition RPC validates sender ownership/group"

# --- Advanced IED objective production ---
check 'VBIED_DRIVEN_CHECKPOINT' "functions/core/fn_execInitActive.sqf" \
  "Exec init can produce driven VBIED checkpoint objective kind"

check 'VBIED_DRIVEN_GATE' "functions/core/fn_execInitActive.sqf" \
  "Exec init can produce driven VBIED gate objective kind"

check 'SB_MARKET_APPROACH' "functions/core/fn_execInitActive.sqf" \
  "Exec init can produce suicide bomber market objective kind"

check 'SB_CHECKPOINT_APPROACH' "functions/core/fn_execInitActive.sqf" \
  "Exec init can produce suicide bomber checkpoint objective kind"

check 'SB_SHURA_APPROACH' "functions/core/fn_execInitActive.sqf" \
  "Exec init can produce suicide bomber shura objective kind"

check '_canProduceSuicideBomber = _iedTierKnown && { _iedTier >= 3 }' "functions/core/fn_execInitActive.sqf" \
  "Suicide bomber production remains CRITICAL-tier gated"

# --- Stale close detection in incident closed hook ---
check 'THREAT_CLOSED_STALE' "functions/threat/fn_threatOnIncidentClosed.sqf" \
  "Incident closed hook emits THREAT_CLOSED_STALE for already-CLEANED threats"

check 'ARC_fnc_threatIedCleanupSync' "functions/threat/fn_threatOnIncidentClosed.sqf" \
  "Incident closed hook calls cleanup sync for no-world-ref threats"

check '_stateCapture isEqualTo "CLEANED"' "functions/threat/fn_threatOnIncidentClosed.sqf" \
  "Incident closed hook checks CLEANED state before driving transition"

# --- Implementation documentation ---
check 'Spawn idempotency' "docs/planning/threat/Threat_IED_Lifecycle_Implementation_v1.md" \
  "Epic 2 implementation doc covers spawn idempotency"

check 'CLOSED_STALE' "docs/planning/threat/Threat_IED_Lifecycle_Implementation_v1.md" \
  "Epic 2 implementation doc covers stale close handling"

check 'spawn_token' "docs/planning/threat/Threat_IED_Lifecycle_Implementation_v1.md" \
  "Epic 2 implementation doc documents spawn_token field"

check 'Complex/chain IED status' "docs/planning/threat/Threat_IED_Lifecycle_Implementation_v1.md" \
  "Epic 2 implementation doc declares complex/chain IED status"

check 'Reachable from ARC_fnc_iedSpawnTick' "functions/ied/fn_iedComplexAttackStage.sqf" \
  "Complex attack module documents its runtime reachability path"

check 'Reachable from ARC_fnc_iedSpawnTick' "functions/ied/fn_iedChainEmplace.sqf" \
  "Chain IED module documents its runtime reachability path"

if [[ "$pass" != true ]]; then
  exit 1
fi
