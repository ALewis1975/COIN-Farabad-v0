"""Threat repair control-flow checks plus optional actual-SQF data regression.
Run: python tests/static/critical_threat_lifecycle_checks.py --sqfvm PATH
Host adapters are explicit: isServer -> true, serverTime -> ARC_TEST_clock,
mapGridPosition -> str, trim -> identity for whitespace-free fixture inputs,
and public snapshot restoration -> local only. Intel/event/debug sinks are inert in VM only. Production
stateGet/stateSet, runtime identity, cleanup, transitions and maintenance execute.
No scheduler, physics, locality, networking or explosion simulation is claimed.
"""
from pathlib import Path
import argparse
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r'/\*.*?\*/|//[^\n]*|"(?:""|[^"])*"|\'(?:\'\'|[^\'])*\'|\b\w+\b|&&|\|\||>=|<=|!=|==|[^\s]', re.S)

def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')

def tokens(source):
    return [m.group() for m in TOKEN.finditer(source) if not m.group().startswith(('//', '/*'))]

def code(path):
    return ' '.join(tokens(read(path)))

def host_adapt(source):
    replacements = {'isServer': 'true', 'serverTime': 'ARC_TEST_clock', 'mapGridPosition': 'str'}
    adapted = TOKEN.sub(lambda m: replacements.get(m.group(), m.group()), source)
    adapted = adapted.replace("params ['_s']; trim _s", "params ['_s']; _s")
    return adapted.replace(',_key isEqualTo "threat_v0_events_public"]', ']')

def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sqfvm', type=Path)
    args = parser.parse_args()
    checks = 0
    def check(ok, name):
        nonlocal checks
        assert ok, name
        checks += 1
        print('PASS', name)
    # Braces, not indentation: the denied tier exit must belong to the function.
    for filename in ('vbiedSpawnTick', 'vbiedDrivenSpawnTick', 'suicideBomberSpawnTick'):
        ts = tokens(read(f'functions/ied/fn_{filename}.sqf'))
        depth = 0
        found = False
        for i, tok in enumerate(ts):
            if tok == 'exitWith' and '_tier' in ts[max(0, i-18):i]:
                check(depth == 0, f'{filename} tier denial exits function scope')
                found = True
                break
            depth += (tok == '{') - (tok == '}')
        check(found, f'{filename} tier gate exercised by scope inspection')
    parked = code('functions/ied/fn_vbiedSpawnTick.sqf')
    check('if ( ! _alreadyArmed && { _last >= 0 }' in parked, 'parked cooldown applies only before admission')
    check(parked.count('[ "activeVbiedLastArmedAt" , serverTime ]') == 1, 'single arm timestamp writer')
    driven = code('functions/ied/fn_vbiedDrivenSpawnTick.sqf')
    reserve = driven.index('setVariable [ "threat_v0_drivenPending" , [ _taskId , _threatId ]')
    worker = driven.index('] spawn {')
    check(reserve < worker < driven.index('sleep _delay'), 'reservation precedes worker and suspension')
    wake = driven[driven.index('sleep _delay'):driven.index('private _veh = createVehicle')]
    check(all(x in wake for x in ('RESERVATION_CHANGED', 'TASK_CHANGED', 'TIER_CHANGED', 'NO_PLAYERS_AT_SPAWN', 'TOD_DENIED')), 'wake revalidates ownership and admission')
    for file, sleep in [('vbiedDrivenSpawnTick', 'sleep 3'), ('suicideBomberSpawnTick', 'sleep 2')]:
        src = code(f'functions/ied/fn_{file}.sqf')
        monitor = src[src.index(sleep):]
        check(monitor.index('call ARC_fnc_threatRuntimeIsCurrent') < monitor.index('call ARC_fnc_' + ('vbiedServerDetonate' if file.startswith('vbied') else 'suicideBomberOnDetonate')), f'{file} validates identity before detonation')
        check('remoteExec' not in monitor, f'{file} server monitor calls local endpoint')
        check(not re.search(r'select [01] [+-]', src), f'{file} scalar coordinate selection precedes arithmetic')
    cleanup = code('functions/core/fn_execCleanupActive.sqf')
    check(cleanup.index('terminate _worker') < cleanup.index('deleteVehicle'), 'cleanup cancels workers before deleting actors')
    for field in ('Safe', 'Alerted', 'AlertAt', 'PauseAccum', 'PauseSince', 'WindowRemaining'):
        check(f'"activeVbied{field}"' in cleanup and f'"activeVbied{field}"' in code('functions/core/fn_execInitActive.sqf'), f'parked {field} resets on cleanup and new package')
    sync = code('functions/threat/fn_threatIedCleanupSync.sqf')
    check(sync.index('if ( _remaining > 0 ) exitWith') < sync.index('[ _threatId , "CLEANED"'), 'cleanup waits for every companion before terminal transition')
    check('groups_net_ids' in sync and 'units_net_ids' in sync, 'cleanup covers group and unit references')
    scheduler = code('functions/threat/fn_threatSchedulerTick.sqf')
    check(scheduler.index('call ARC_fnc_threatMaintenanceTick') < scheduler.index('private _openDistricts'), 'retirement precedes district admission')
    check('if ( serverTime >= _nextReset )' in scheduler and '_todayDay !=' not in scheduler, 'budget reset uses persisted deadline')
    rebuild = read('functions/core/fn_execInitActive.sqf').split('// PHYSICAL_REBUILD_PRESERVE_BEGIN:', 1)[1].split('// PHYSICAL_REBUILD_PRESERVE_END', 1)[0]
    rebuild = rebuild[rebuild.index('\n'):]
    check(rebuild.index('_savedProgress pushBack') < rebuild.index('_ok = [] call ARC_fnc_execInitActive') < rebuild.index('forEach _savedProgress'), 'physical rebuild captures progress before reconstruction and restores after')
    check('isEqualTo _taskId' in rebuild and 'activeIncidentAccepted' in rebuild, 'physical rebuild preservation requires accepted same task')
    check('_elapsed = _elapsed + ( _elapsedCarry max 0 )' in parked, 'parked countdown includes persisted elapsed carry')
    init_source = code('functions/core/fn_execInitActive.sqf')
    check(init_source.index('if ( [ "activeIncidentCloseReady" , false ] call ARC_fnc_stateGet ) exitWith { true }') < init_source.index('if ( _needsBuild )'), 'completed awaiting-SITREP task exits before any physical rebuild')
    print(f'STATIC SUMMARY {checks} checks passed')
    if args.sqfvm:
        setup = 'ARC_TEST_clock = 1000; missionNamespace setVariable ["ARC_criticalRepairTestsEnabled",true];\n'
        setup += 'ARC_fnc_intelLog = {""}; ARC_fnc_threatDebugSnapshot = {[]}; ARC_fnc_threatEmitEvent = {[]};\n'
        for folder, fn in [('core','stateGet'),('core','stateSet'),('threat','threatRuntimeIsCurrent'),('threat','threatUpdateState'),('threat','threatIedCleanupSync'),('threat','threatMaintenanceTick')]:
            setup += f'ARC_fnc_{fn} = {{\n{host_adapt(read(f"functions/{folder}/fn_{fn}.sqf"))}\n}};\n'
        setup += host_adapt(read('tests/critical_threat_lifecycle.sqf'))
        # Execute the production preservation block with physical creation stubbed.
        # This tests capture/restore and task guards, not world reconstruction.
        setup += ';\nARC_TEST_rebuildBlock = {\n' + host_adapt(rebuild).replace(', true];', '];') + '\n};\n'
        setup += r'''
ARC_fnc_taskUpdateActiveDescription = {};
missionNamespace setVariable ["ARC_stateWriteGen",0];
ARC_fnc_execInitActive = {
    ["activeExecTaskId","TASK-A"] call ARC_fnc_stateSet;
    ["activeExecDeadlineAt",1800] call ARC_fnc_stateSet;
    ["activeExecArrivalReq",900] call ARC_fnc_stateSet;
    ["activeExecHoldAccum",0] call ARC_fnc_stateSet;
    ["activeExecActivated",false] call ARC_fnc_stateSet;
    ["activeVbiedElapsedBeforeLoad",0] call ARC_fnc_stateSet;
    ["activeVbiedDeviceId",""] call ARC_fnc_stateSet;
    if (_replaceTask) then {["activeTaskId","TASK-B"] call ARC_fnc_stateSet};
    _buildSuccess
};
private _rebuildPass = 0;
private _checkRebuild = {params ["_ok","_message"]; if (!_ok) then {throw _message}; _rebuildPass = _rebuildPass + 1;};
{
    _x params ["_accepted","_oldTask","_replaceTask","_buildSuccess","_expectPreserve"];
    missionNamespace setVariable ["ARC_state",[]];
    { _x call ARC_fnc_stateSet; } forEach [["activeTaskId","TASK-A"],["activeIncidentAccepted",_accepted],["activeObjectiveKind","VBIED_VEHICLE"],["activeExecDeadlineAt",630],["activeExecArrivalReq",430],["activeExecHoldAccum",125],["activeExecActivated",true],["activeVbiedElapsedBeforeLoad",40],["activeVbiedDeviceId","VBIED_STABLE"]];
    private _taskId = "TASK-A";
    private _execTaskId = _oldTask;
    private _objKindNow = "VBIED_VEHICLE";
    private _pos = [100,100,0];
    private _ok = false;
    call ARC_TEST_rebuildBlock;
    [(["activeExecDeadlineAt",0] call ARC_fnc_stateGet) isEqualTo (if (_expectPreserve) then {630} else {1800}),"physical rebuild deadline guard"] call _checkRebuild;
    [(["activeExecHoldAccum",0] call ARC_fnc_stateGet) isEqualTo (if (_expectPreserve) then {125} else {0}),"physical rebuild hold guard"] call _checkRebuild;
    [(["activeVbiedElapsedBeforeLoad",0] call ARC_fnc_stateGet) isEqualTo (if (_expectPreserve) then {40} else {0}),"physical rebuild VBIED carry guard"] call _checkRebuild;
    [(["activeVbiedDeviceId",""] call ARC_fnc_stateGet) isEqualTo (if (_expectPreserve) then {"VBIED_STABLE"} else {""}),"physical rebuild device identity guard"] call _checkRebuild;
} forEach [[true,"TASK-A",false,true,true],[true,"TASK-OLD",false,true,false],[false,"TASK-A",false,true,false],[true,"TASK-A",true,true,false],[true,"TASK-A",false,false,false]];
diag_log format ["REBUILD SUMMARY pass=%1 fail=0",_rebuildPass];
'''
        with tempfile.TemporaryDirectory(prefix='arc-threat-tests-') as temp:
            harness = Path(temp) / 'critical_threat.sqf'
            harness.write_text(setup, encoding='utf-8')
            proc = subprocess.run([str(args.sqfvm.resolve()), '--automated', '--suppress-welcome', '--input-sqf', str(harness)], cwd=ROOT, text=True, capture_output=True)
            output = proc.stdout + proc.stderr
            print(output)
            assert proc.returncode == 0 and '[ERR]' not in output and '[FAT]' not in output, 'VM execution failure'
            assert 'SUMMARY pass=19 fail=0' in output, 'VM behavioral assertions failed or did not execute'
            assert 'REBUILD SUMMARY pass=20 fail=0' in output, 'physical reconstruction preservation assertions failed'

if __name__ == '__main__':
    run()
