#!/usr/bin/env python3
"""Execute actual next-incident flow in a VM fixture with mutation tripwires.
Engine identity/network/dependencies are explicit stand-ins; not MP validation.
"""
from pathlib import Path
import argparse
import re
import subprocess
import tempfile
from security_rejection_flow_checks import ROOT, TOKEN, blocks


def run_vm(exe, path):
    result = subprocess.run([str(exe),'--automated','--suppress-welcome','--no-execute-print','--input-sqf',str(path)],cwd=ROOT,capture_output=True,text=True,timeout=30)
    output = result.stdout + result.stderr
    return output, '[ERR]' not in output and '[FAT]' not in output


def next_flow(exe):
    source = (ROOT/'functions/core/fn_tocRequestNextIncident.sqf').read_text(encoding='utf-8-sig')
    changes = {'isServer':'true','isRemoteExecuted':'false','remoteExecutedOwner':'0','allPlayers':'[]','serverTime':'100','diag_tickTime':'100'}
    source = ''.join(changes.get(m[0],m[0]) for m in TOKEN.finditer(source))
    # VM lacks trim; fixture tokens have no whitespace, so identity is exact here.
    source = source.replace("compile \"params ['_s']; trim _s\"", "{params ['_s']; _s}")
    # Public-variable transport is outside the VM model; preserve payload storage.
    source = source.replace(",\n        true\n    ];", "\n    ];").replace(",\n            true\n        ];", "\n        ];")
    header = '''
ARC_fnc_rpcValidateSender = {true};
ARC_fnc_rolesCanApproveQueue = {true};
ARC_fnc_rolesHasGroupIdToken = {false};
ARC_fnc_securityDenyRecord = {true};
ARC_fnc_intelLog = {true};
ARC_fnc_stateGet = {params ["_key","_default"]; missionNamespace getVariable ["ARC_NEXT_" + _key,_default]};
ARC_fnc_stateSet = {params ["_key","_value"]; ARC_NEXT_writes = ARC_NEXT_writes + 1; missionNamespace setVariable ["ARC_NEXT_" + _key,_value]; true};
ARC_fnc_tocBacklogPopNext = {ARC_NEXT_pops = ARC_NEXT_pops + 1; ["lead1"]};
ARC_fnc_incidentCreate = {ARC_NEXT_creates = ARC_NEXT_creates + 1; ARC_NEXT_createResult};
ARC_fnc_taskRehydrateActive = {ARC_NEXT_rehydrates = ARC_NEXT_rehydrates + 1; true};
ARC_NEXT_assert = {params ["_ok","_label"]; if (!_ok) then {throw _label;};};
ARC_NEXT_setup = {
    params ["_orders",["_active",""]];
    missionNamespace setVariable ["ARC_NEXT_activeTaskId",_active]; missionNamespace setVariable ["ARC_NEXT_lastTaskingGroup","RF1"]; missionNamespace setVariable ["ARC_NEXT_tocOrders",_orders]; missionNamespace setVariable ["ARC_NEXT_autoIncidentSuspendUntil",999];
    ARC_NEXT_writes = 0; ARC_NEXT_pops = 0; ARC_NEXT_creates = 0; ARC_NEXT_rehydrates = 0; ARC_NEXT_createResult = true;
    missionNamespace setVariable ["ARC_allowIncidentDuringAcceptedRtb",false];
};
'''
    cases = '''
[[["o",0,"ISSUED","HOLD","RF1",[],[]]]] call ARC_NEXT_setup;
private _r = [objNull] call ARC_NEXT_underTest;
[(_r isEqualTo false) && {ARC_NEXT_pops == 0} && {ARC_NEXT_creates == 0} && {ARC_NEXT_writes == 0},"issued denial leaked mutation"] call ARC_NEXT_assert;
[[["o",0,"ACCEPTED","RTB","RF1",[],[]]]] call ARC_NEXT_setup;
_r = [objNull] call ARC_NEXT_underTest;
[(_r isEqualTo false) && {ARC_NEXT_pops == 0} && {ARC_NEXT_creates == 0} && {ARC_NEXT_writes == 0},"RTB denial leaked mutation"] call ARC_NEXT_assert;
missionNamespace setVariable ["ARC_allowIncidentDuringAcceptedRtb",true];
_r = [objNull] call ARC_NEXT_underTest;
[(_r isEqualTo true) && {ARC_NEXT_pops == 1} && {ARC_NEXT_creates == 1} && {ARC_NEXT_writes == 1},"authorized policy override blocked"] call ARC_NEXT_assert;
[[]] call ARC_NEXT_setup;
_r = [objNull] call ARC_NEXT_underTest;
[(_r isEqualTo true) && {ARC_NEXT_pops == 1} && {ARC_NEXT_creates == 1},"eligible generation must occur once"] call ARC_NEXT_assert;
[[]] call ARC_NEXT_setup;
ARC_NEXT_createResult = false;
_r = [objNull] call ARC_NEXT_underTest;
[(_r isEqualTo false) && {((missionNamespace getVariable ["ARC_pub_nextIncidentResult",[]]) select 2) isEqualTo "CREATE_FAILED"},"creator failure reported as success"] call ARC_NEXT_assert;
[[],"active1"] call ARC_NEXT_setup;
_r = [objNull] call ARC_NEXT_underTest;
[(_r isEqualTo true) && {ARC_NEXT_rehydrates == 1} && {ARC_NEXT_creates == 0} && {ARC_NEXT_pops == 0},"active incident must only rehydrate"] call ARC_NEXT_assert;
diag_log "[ARC][NEXT_FLOW] ALL_PASS cases=6";
'''
    for mutant in [False,True]:
        body = source
        if mutant:
            body = body.replace('if (!_generationAllowed) exitWith { false };','// removed outer denial guard',1)
        fixture = header+'\nARC_NEXT_underTest = {\n'+body+'\n};\n'+cases
        with tempfile.TemporaryDirectory(prefix='farabad-next-') as directory:
            path=Path(directory)/'next.sqf';path.write_text(fixture,encoding='utf-8')
            output,clean=run_vm(exe,path)
        passed=clean and '[ARC][NEXT_FLOW] ALL_PASS' in output
        assert passed != mutant, f'next flow mutant={mutant}\n{output}'
    print('PASS: six production NextIncident cases; removed-policy-guard mutant rejected')


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--sqfvm',type=Path,required=True);args=parser.parse_args();exe=args.sqfvm.resolve()
    output,clean=run_vm(exe,ROOT/'tests/command_critical_regression.sqf')
    assert clean and '[ARC][COMMAND_TEST] ALL_PASS' in output,output
    print(output.strip())
    next_flow(exe)
