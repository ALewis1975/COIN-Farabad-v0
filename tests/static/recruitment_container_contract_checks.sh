#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

required_files=(
  "functions/core/fn_rolesCanRecruitAI.sqf"
  "functions/logistics/fn_recruitClientInit.sqf"
  "functions/logistics/fn_recruitClientAddActions.sqf"
  "functions/logistics/fn_recruitSpawnRequest.sqf"
)

for file in "${required_files[@]}"; do
  test -f "$file"
done

grep -q 'class rolesCanRecruitAI' config/CfgFunctions.hpp
grep -q 'class recruitClientInit' config/CfgFunctions.hpp
grep -q 'class recruitClientAddActions' config/CfgFunctions.hpp
grep -q 'class recruitSpawnRequest' config/CfgFunctions.hpp
grep -q 'class ARC_fnc_recruitSpawnRequest[[:space:]]*{ allowedTargets = 2; };' config/CfgRemoteExec.hpp

grep -q 'ARC_recruitContainerEnabled' initServer.sqf
grep -q 'ARC_recruitUnitWhitelist' initServer.sqf
grep -q 'B_Slingload_01_Cargo_F' initServer.sqf
grep -q 'ARC_isRecruitContainer' initServer.sqf
grep -q 'ARC_fnc_recruitClientInit' initPlayerLocal.sqf

grep -q 'ARC_fnc_rpcValidateSender' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_fnc_rolesCanRecruitAI' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_isRecruitContainer' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_recruitUnitWhitelist' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'createUnit' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'joinSilent' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_recruitRequireSameFaction' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_isRecruitContainer' functions/logistics/fn_recruitClientInit.sqf
! grep -q 'ARC_recruitContainerPositions' functions/logistics/fn_recruitClientInit.sqf
! grep -q 'ARC_recruitContainerPositionRadiusM' functions/logistics/fn_recruitClientInit.sqf
! grep -q 'ARC_recruitContainerPositions' functions/logistics/fn_recruitSpawnRequest.sqf
! grep -q 'ARC_recruitContainerPositionRadiusM' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'remoteExec \["ARC_fnc_recruitSpawnRequest", 2\]' functions/logistics/fn_recruitClientAddActions.sqf

echo "[PASS] recruitment container contract checks"
