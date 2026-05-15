#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

required_files=(
  "functions/logistics/fn_recruitClientInit.sqf"
  "functions/logistics/fn_recruitClientAddActions.sqf"
  "functions/logistics/fn_recruitDialogOpen.sqf"
  "functions/logistics/fn_recruitDialogOnLoad.sqf"
  "functions/logistics/fn_recruitDialogRecruitSelected.sqf"
  "functions/logistics/fn_recruitServerPublishContainers.sqf"
  "functions/logistics/fn_recruitSpawnRequest.sqf"
)

for file in "${required_files[@]}"; do
  test -f "$file"
done

grep -q 'class recruitClientInit' config/CfgFunctions.hpp
grep -q 'class recruitClientAddActions' config/CfgFunctions.hpp
grep -q 'class recruitDialogOpen' config/CfgFunctions.hpp
grep -q 'class recruitDialogOnLoad' config/CfgFunctions.hpp
grep -q 'class recruitDialogRecruitSelected' config/CfgFunctions.hpp
grep -q 'class recruitServerPublishContainers' config/CfgFunctions.hpp
grep -q 'class recruitSpawnRequest' config/CfgFunctions.hpp
grep -q 'class ARC_fnc_recruitSpawnRequest[[:space:]]*{ allowedTargets = 2; };' config/CfgRemoteExec.hpp
grep -q 'class ARC_fnc_recruitClientAddActions[[:space:]]*{ allowedTargets = 0; jip = 1; };' config/CfgRemoteExec.hpp
grep -q 'class ARC_RecruitDialog' config/CfgDialogs.hpp
python3 - <<'PY'
from pathlib import Path
import sys

text = Path("config/CfgDialogs.hpp").read_text()
needle = "class ARC_RecruitDialog"
idx = text.find(needle)
if idx < 0:
    sys.exit("ARC_RecruitDialog missing from config/CfgDialogs.hpp")

depth = 0
in_string = None
in_line_comment = False
in_block_comment = False
escaped = False
pos = 0
while pos < idx:
    ch = text[pos]
    nxt = text[pos + 1] if pos + 1 < idx else ""

    if in_line_comment:
        if ch == "\n":
            in_line_comment = False
        pos += 1
        continue
    if in_block_comment:
        if ch == "*" and nxt == "/":
            in_block_comment = False
            pos += 2
        else:
            pos += 1
        continue
    if in_string:
        if escaped:
            escaped = False
        elif ch == "\\":
            escaped = True
        elif ch == in_string:
            in_string = None
        pos += 1
        continue

    if ch == "/" and nxt == "/":
        in_line_comment = True
        pos += 2
        continue
    if ch == "/" and nxt == "*":
        in_block_comment = True
        pos += 2
        continue
    if ch in ("'", '"'):
        in_string = ch
        pos += 1
        continue
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth < 0:
            sys.exit("config/CfgDialogs.hpp has an unexpected closing brace before ARC_RecruitDialog")
    pos += 1

if depth != 0:
    sys.exit(f"ARC_RecruitDialog is not top-level in config/CfgDialogs.hpp (brace depth {depth})")
PY

grep -q 'ARC_recruitContainerEnabled' initServer.sqf
grep -q 'ARC_recruitContainerNetIds' initServer.sqf
grep -q 'ARC_recruitContainerNames' initServer.sqf
grep -q 'recruitment_01' initServer.sqf
grep -q 'B_Slingload_01_Cargo_F' initServer.sqf
grep -q 'ARC_isRecruitContainer' initServer.sqf
grep -q 'ARC_fnc_recruitClientInit' initPlayerLocal.sqf

grep -q 'ARC_fnc_rpcValidateSender' functions/logistics/fn_recruitSpawnRequest.sqf
! grep -q 'ARC_fnc_rolesCanRecruitAI' functions/logistics/fn_recruitSpawnRequest.sqf
! grep -q 'ARC_recruitUnitWhitelist' functions/logistics/fn_recruitSpawnRequest.sqf
! grep -q 'ARC_recruitRequireSameFaction' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_isRecruitContainer' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'isKindOf "CAManBase"' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'faction _caller' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_recruitGroupMaxUnits' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'createUnit' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'joinSilent' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'ARC_recruitContainerNetIds' functions/logistics/fn_recruitServerPublishContainers.sqf
grep -q 'ARC_recruitContainerNames' functions/logistics/fn_recruitServerPublishContainers.sqf
grep -q 'ARC_isRecruitContainer' functions/logistics/fn_recruitServerPublishContainers.sqf
grep -q 'allMissionObjects' functions/logistics/fn_recruitServerPublishContainers.sqf
grep -q 'remoteExec \["ARC_fnc_recruitClientAddActions", 0, _container\]' functions/logistics/fn_recruitServerPublishContainers.sqf
grep -q 'objectFromNetId' functions/logistics/fn_recruitClientInit.sqf
grep -q 'ARC_recruitContainerNetIds' functions/logistics/fn_recruitClientInit.sqf
grep -q 'ARC_isRecruitContainer' functions/logistics/fn_recruitClientInit.sqf
! grep -q 'ARC_recruitContainerPositions' functions/logistics/fn_recruitClientInit.sqf
! grep -q 'ARC_recruitContainerPositionRadiusM' functions/logistics/fn_recruitClientInit.sqf
! grep -q 'ARC_recruitContainerPositions' functions/logistics/fn_recruitSpawnRequest.sqf
! grep -q 'ARC_recruitContainerPositionRadiusM' functions/logistics/fn_recruitSpawnRequest.sqf
grep -q 'Recruit AI' functions/logistics/fn_recruitClientAddActions.sqf
grep -q 'ARC_fnc_recruitDialogOpen' functions/logistics/fn_recruitClientAddActions.sqf
grep -q 'configClasses' functions/logistics/fn_recruitDialogOnLoad.sqf
grep -q 'remoteExec \["ARC_fnc_recruitSpawnRequest", 2\]' functions/logistics/fn_recruitDialogRecruitSelected.sqf

echo "[PASS] recruitment container contract checks"
