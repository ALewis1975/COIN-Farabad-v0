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

check 'Threat Persistence / Migration / Reset Implementation v1' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Epic 5 implementation doc added"
check 'Threat schema/version contract' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Doc includes schema/version contract section"
check 'Migration matrix and idempotency rules' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Doc includes migration matrix/idempotency section"
check 'Reset/rebuild contract' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Doc includes reset/rebuild contract"
check 'Restart invariants checklist' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Doc includes restart invariants checklist"
check 'BLOCKED \(runtime restart\)' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Doc keeps controlled restart evidence blocked"
check 'BLOCKED \(dedicated/JIP\)' "docs/planning/threat/Threat_Persistence_Migration_Reset_Implementation_v1.md" "Doc keeps dedicated/JIP evidence blocked"

check 'threat_v0_version' "functions/threat/fn_threatInit.sqf" "Threat init seeds threat_v0_version"
check 'threat_v0_family_contract_v' "functions/threat/fn_threatInit.sqf" "Threat init seeds family contract version"
check 'threat_v0_state_enum' "functions/threat/fn_threatInit.sqf" "Threat init seeds state enum"
check 'threat_v0_deny_reason_enum' "functions/threat/fn_threatInit.sqf" "Threat init seeds deny reason enum"
check 'ARC_fnc_threatEconomyInit' "functions/threat/fn_threatInit.sqf" "Threat init invokes economy init"

check 'threat_v0_campaign_id' "functions/core/fn_resetAll.sqf" "Reset path clears campaign id"
check 'threat_v0_records' "functions/core/fn_resetAll.sqf" "Reset path clears threat records"
check 'threat_v0_open_index' "functions/core/fn_resetAll.sqf" "Reset path clears open index"
check 'threat_v0_closed_index' "functions/core/fn_resetAll.sqf" "Reset path clears closed index"
check 'ARC_fnc_threatInit' "functions/core/fn_resetAll.sqf" "Reset path re-runs threat init"

check 'ARC_fnc_stateLoad' "functions/core/fn_bootstrapServer.sqf" "Bootstrap loads persisted state before threat init"
check 'ARC_fnc_threatVirtualPoolInit' "functions/core/fn_bootstrapServer.sqf" "Bootstrap invokes virtual pool init"
check 'ARC_fnc_publicBroadcastState' "functions/core/fn_bootstrapServer.sqf" "Bootstrap republishes public snapshots after init"
check 'ARC_pub_threatEconomySnapshot' "functions/core/fn_publicBroadcastState.sqf" "Public broadcast replicates threat economy snapshot"
check 'ARC_pub_threatVirtualPoolSnapshot' "functions/core/fn_publicBroadcastState.sqf" "Public broadcast replicates virtual pool snapshot"

check 'THREAT-MIG-001-vLegacy-minimal' "tests/migrations/threat_persistence_schema_scenarios.json" "Threat migration fixture includes legacy baseline scenario"
check 'THREAT-MIG-002-vPartial-replay-safe' "tests/migrations/threat_persistence_schema_scenarios.json" "Threat migration fixture includes replay-safe partial scenario"
check 'THREAT-MIG-003-v0-noop-idempotent' "tests/migrations/threat_persistence_schema_scenarios.json" "Threat migration fixture includes v0 idempotent no-op scenario"

python3 scripts/dev/validate_state_migrations.py --scenarios tests/migrations/threat_persistence_schema_scenarios.json

if [[ "$pass" != true ]]; then
  exit 1
fi
