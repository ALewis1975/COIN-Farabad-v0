#!/usr/bin/env python3
"""Bounded rejection-flow regression, not a dedicated-MP security proof.

Checks lexical scope on production guards. With --sqfvm, executes the actual
three privileged wrapper bodies with explicit stand-ins for unimplemented
engine/network commands and dependencies. Mutation callbacks are tripwires.
The sender helper is deliberately stubbed: real sender identity is covered by
the separate in-engine harness, not asserted by this VM model.
An old-style nested-exit mutation must FAIL the same behavioral cases.
"""
from pathlib import Path
import argparse
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:""|[^"])*"|\'(?:\'\'|[^\'])*\'|[A-Za-z_][A-Za-z_0-9]*|.', re.S)


def masked(source):
    return ''.join(' ' * len(m[0]) if m[0].startswith(('//', '/*', '"', "'")) else m[0]
                   for m in TOKEN.finditer(source))


def blocks(source):
    code = masked(source)
    stack, pairs, ancestors = [], {}, {}
    for i, c in enumerate(code):
        ancestors[i] = tuple(stack)
        if c == '{':
            stack.append(i)
        elif c == '}':
            assert stack, f'unmatched closing brace at {i}'
            pairs[stack.pop()] = i
    assert not stack, 'unclosed brace'
    return code, pairs, ancestors


def rejection_propagates(source):
    code, pairs, ancestors = blocks(source)
    result_scopes = {}
    for m in re.finditer(r'private\s+(_(?:rpc|detonation|sender)Authorized)\s*=\s*if\b', code):
        then = re.search(r'\bthen\s*\{', code[m.end():])
        assert then, 'result guard has no then body'
        start = m.end() + then.end() - 1
        end = pairs[start]
        reject = re.search(r'if\s*\(\s*!\s*' + m[1] + r'\s*\)\s*exitWith\s*\{', code[end+1:])
        if reject:
            at = end + 1 + reject.start()
            if not ancestors[at]:
                result_scopes[start] = at
    calls = list(re.finditer(r'call\s+ARC_fnc_rpcValidateSender\b', code))
    assert calls, 'no sender check'
    for call in calls:
        chain = ancestors[call.start()]
        if not chain:
            # Direct function-scope validation must feed exitWith or a checked result.
            tail = code[call.end():call.end()+100]
            assert re.search(r'\)\s*\)*\s*exitWith', tail), 'unchecked top-level sender result'
        else:
            assert len(chain) == 1 and chain[0] in result_scopes, 'nested sender denial does not leave function'
    return True


DIRECT = [
    *[f'civsub/fn_{n}.sqf' for n in ('civsubContactReqAction','civsubContactReqSnapshot','civsubInteractCheckPapers','civsubInteractDetain','civsubInteractEndSession','civsubInteractHandoffSheriff','civsubInteractOrderStop','civsubInteractRelease','civsubInteractShowPapers','civsubRunMdtByNetId')],
    *[f'command/fn_{n}.sqf' for n in ('intelQueueSubmit','intelTocIssueLead','intelTocIssueOrder','intelOrderCompleteRtbEpw','intelOrderCompleteRtbIntel')],
    'ied/fn_iedCollectEvidence.sqf','medical/fn_medicalCasevacRequest.sqf','core/fn_execObjectiveComplete.sqf',
]
GUARDED = [
    *[f'core/fn_{n}.sqf' for n in ('tocRequestResetAll','tocRequestSave','tocRequestRebuildActive','tocRequestCivsubReset','tocRequestCivsubSave','tocRequestAirbaseResetControlState','tocRequestPublicBroadcast','tocRequestRefreshIntel','tocRequestShowLeads','tocRequestAcceptIncident','devToggleDebugMode','devCompileAuditServer','devDiagnosticsSnapshot','uiConsoleQAAuditServer','uiConsoleTestRunServer','uiCoverageAuditServer','missionScoreGenerate')],
    'ied/fn_iedServerDetonate.sqf','ied/fn_vbiedServerDetonate.sqf','ied/fn_iedServerRequestDisposition.sqf',
]


def static_checks():
    old = 'if (_remote) then { if (!([] call ARC_fnc_rpcValidateSender)) exitWith {false}; }; MUTATION;'
    try:
        rejection_propagates(old)
    except AssertionError:
        pass
    else:
        raise AssertionError('negative control: nested exit accepted')
    good = 'private _rpcAuthorized = if (_remote) then { if (!([] call ARC_fnc_rpcValidateSender)) exitWith {false}; true } else {true}; if (!_rpcAuthorized) exitWith {false}; MUTATION;'
    rejection_propagates(good)
    for rel in DIRECT + GUARDED:
        try:
            rejection_propagates((ROOT / 'functions' / rel).read_text(encoding='utf-8-sig'))
        except AssertionError as e:
            raise AssertionError(f'{rel}: {e}') from e
    cfg = masked((ROOT / 'config/CfgRemoteExec.hpp').read_text(encoding='utf-8-sig'))
    assert not re.search(r'class\s+(?:BIS_fnc_holdActionAdd|ARC_fnc_suicideBomberOnDetonate)\b', cfg)
    print(f'PASS: {len(DIRECT + GUARDED)} production guard scopes, nested-exit negative control, client code surface')


def model_engine(source):
    # These substitutions exist in a generated temporary VM fixture only.
    # No engine-reserved identifiers are overwritten, and production is unchanged.
    changes = {'isServer':'true', 'isRemoteExecuted':'ARC_FLOW_remote',
               'remoteExecutedOwner':'ARC_FLOW_owner', 'allPlayers':'[]', 'serverTime':'100'}
    source = ''.join(changes.get(m[0], m[0]) for m in TOKEN.finditer(source))
    # Notification delivery is outside this control-flow test (VM lacks remoteExec).
    return re.sub(r'^\s*\["Rebuild active incident rejected: insufficient privileges\."\] remoteExec .*?;',
                  '        [] call ARC_FLOW_ignoreNotification;', source, flags=re.M)


def lose_result_guard(source):
    code, pairs, _ = blocks(source)
    m = re.search(r'if\s*\(!_rpcAuthorized\)\s*exitWith\s*\{', code)
    assert m
    end = pairs[m.end()-1] + 2
    source = source[:m.start()] + source[end:]
    return source.replace('private _rpcAuthorized = if', 'if', 1)


def rtb_vm_checks(executable):
    for name, purpose in [('intelOrderCompleteRtbIntel','INTEL'),('intelOrderCompleteRtbEpw','EPW')]:
        source = (ROOT / f'functions/command/fn_{name}.sqf').read_text(encoding='utf-8-sig')
        _, pairs, _ = blocks(source)
        get_start = source.index('private _getPair =')
        get_brace = source.index('{',get_start)
        getter = source[get_start:pairs[get_brace]+2]
        select_start = source.index('private _selectionAllowed =')
        select_end = source.index('if (!_selectionAllowed) exitWith {false};',select_start)+len('if (!_selectionAllowed) exitWith {false};')
        selection = source[select_start:select_end]
        proximity_start = source.index('private _atDestination =')
        proximity_end = source.index('// Update order status + metadata',proximity_start) if purpose == 'INTEL' else source.index('// Resolve EPW holding location',proximity_start)
        proximity = source[proximity_start:proximity_end]
        # Only the engine distance/time/notification boundary is substituted;
        # the actual production lookup and permission/result branches execute.
        proximity = proximity.replace('(_caller distance2D _p)','ARC_RTB_distance').replace('serverTime','100')
        proximity = '\n'.join(line for line in proximity.splitlines() if 'remoteExec [' not in line)
        header = '''
ARC_RTB_assert = {params ["_ok","_label"]; if (!_ok) then {throw _label;};};
'''+getter+'\n'
        checks = '''
private _record = ["o1",0,"ACCEPTED","RTB","RF",[["purpose","PURPOSE"]],[]];
[([[["purpose","PURPOSE"]],"purpose","REFIT"] call _getPair) isEqualTo "PURPOSE","lookup discarded found value"] call ARC_RTB_assert;
[([[],"purpose","REFIT"] call _getPair) isEqualTo "REFIT","lookup lost fallback"] call ARC_RTB_assert;
[[true,"o1",[_record],"RF"] call ARC_RTB_select,"valid override blocked"] call ARC_RTB_assert;
[!([false,"o1",[_record],"RF"] call ARC_RTB_select),"unprivileged override escaped denial"] call ARC_RTB_assert;
private _terminal = +_record; _terminal set [2,"COMPLETED"];
[!([true,"o1",[_terminal],"RF"] call ARC_RTB_select),"terminal order escaped selection denial"] call ARC_RTB_assert;
private _wrong = +_record; _wrong set [5,[["purpose","OTHER"]]];
[!([true,"o1",[_wrong],"RF"] call ARC_RTB_select),"wrong purpose escaped selection denial"] call ARC_RTB_assert;
ARC_RTB_distance = 1;
[[false,[]] call ARC_RTB_proximity,"normal on-site completion blocked"] call ARC_RTB_assert;
ARC_RTB_distance = 1000;
[!([false,[]] call ARC_RTB_proximity),"distant ordinary caller escaped proximity"] call ARC_RTB_assert;
[!([true,[]] call ARC_RTB_proximity),"privileged remote completed before arrival"] call ARC_RTB_assert;
[[true,[["arrivedAt",50]]] call ARC_RTB_proximity,"privileged recorded-arrival completion blocked"] call ARC_RTB_assert;
diag_log "[ARC][RTB_SECURITY] ALL_PASS cases=10";
'''.replace('PURPOSE',purpose)
        for mutant in [False,True]:
            block = selection.replace('if (!_selectionAllowed) exitWith {false};','') if mutant else selection
            fixture = header + '\nARC_RTB_select = {params ["_canForce","_orderIdO","_orders","_gidCaller"]; private _idx = -1; private _ord = [];\n'+block+'\ntrue};\n'
            fixture += '\nARC_RTB_proximity = {params ["_canForce","_meta"]; private _destPos = [10,10,0]; private _destRad = 30; private _orderId = "o1"; private _gidCaller = "RF";\n'+proximity+'\ntrue};\n'+checks
            with tempfile.TemporaryDirectory(prefix='farabad-rtb-security-') as directory:
                path = Path(directory)/'rtb.sqf';path.write_text(fixture,encoding='utf-8')
                result = subprocess.run([str(executable),'--automated','--suppress-welcome','--no-execute-print','--input-sqf',str(path)],capture_output=True,text=True,timeout=30)
            output = result.stdout+result.stderr
            passed = '[ARC][RTB_SECURITY] ALL_PASS' in output and '[ERR]' not in output and '[FAT]' not in output
            assert passed != mutant,f'{name} mutant={mutant}\n{output}'
        print(f'PASS: {name}: ten production lookup/selection/proximity cases; removed-selection-guard mutant rejected')


def vm_checks(executable):
    header = '''
ARC_FLOW_calls = 0;
ARC_FLOW_seenOwner = -1;
ARC_FLOW_sender = false;
ARC_FLOW_role = false;
ARC_fnc_rpcValidateSender = { ARC_FLOW_seenOwner = _this select 5; ARC_FLOW_sender };
ARC_fnc_rolesHasGroupIdToken = {false};
ARC_fnc_rolesCanApproveQueue = {ARC_FLOW_role};
ARC_fnc_securityDenyRecord = {true};
ARC_fnc_intelLog = {true};
ARC_FLOW_ignoreNotification = {true};
ARC_fnc_resetAll = {ARC_FLOW_calls = ARC_FLOW_calls + 1; true};
ARC_fnc_stateSave = {ARC_FLOW_calls = ARC_FLOW_calls + 1; true};
ARC_fnc_taskRehydrateActive = {ARC_FLOW_calls = ARC_FLOW_calls + 1; true};
ARC_FLOW_assert = {params ["_ok", "_name"]; if (!_ok) then {throw _name};};
'''
    cases = '''
// Simulated remote context; caller-owner/test flags cannot override it.
ARC_FLOW_remote = true; ARC_FLOW_owner = 73;
missionNamespace setVariable ["ARC_TEST_mode", true];
missionNamespace setVariable ["ARC_TEST_tocDryRun", true];
missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", true];
ARC_FLOW_sender = false; ARC_FLOW_role = true; ARC_FLOW_calls = 0;
private _r = [objNull, 999] call ARC_FLOW_underTest;
[(_r isEqualTo false) && {ARC_FLOW_calls == 0}, "sender denial reached mutation"] call ARC_FLOW_assert;
[ARC_FLOW_seenOwner == 73, "client supplied owner replaced engine capture"] call ARC_FLOW_assert;
ARC_FLOW_sender = true; ARC_FLOW_role = false; ARC_FLOW_calls = 0;
_r = [objNull, 999] call ARC_FLOW_underTest;
[(_r isEqualTo false) && {ARC_FLOW_calls == 0}, "role denial reached mutation"] call ARC_FLOW_assert;
ARC_FLOW_role = true; ARC_FLOW_calls = 0;
_r = [objNull, 999] call ARC_FLOW_underTest;
[(_r isEqualTo true) && {ARC_FLOW_calls == 1}, "authorized remote did not reach exactly one mutation"] call ARC_FLOW_assert;
// Real local/system path remains valid without manufactured remote identity.
ARC_FLOW_remote = false; ARC_FLOW_owner = 0; ARC_FLOW_calls = 0;
missionNamespace setVariable ["ARC_TEST_mode", false];
_r = [objNull] call ARC_FLOW_underTest;
[(_r isEqualTo true) && {ARC_FLOW_calls == 1}, "local internal path blocked"] call ARC_FLOW_assert;
// Existing local dry-run seam must never call real campaign operations.
missionNamespace setVariable ["ARC_TEST_mode", true];
missionNamespace setVariable ["ARC_TEST_tocDryRun", true];
missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", false];
missionNamespace setVariable [ARC_FLOW_counter, 0];
ARC_FLOW_calls = 0;
_r = [objNull, 73] call ARC_FLOW_underTest;
[(_r isEqualTo false) && {(missionNamespace getVariable [ARC_FLOW_counter,-1]) == 0} && {ARC_FLOW_calls == 0}, "denied local dry-run incremented"] call ARC_FLOW_assert;
missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", true];
_r = [objNull, 73] call ARC_FLOW_underTest;
[(_r isEqualTo true) && {(missionNamespace getVariable [ARC_FLOW_counter,-1]) == 1} && {ARC_FLOW_calls == 0}, "authorized local dry-run escaped"] call ARC_FLOW_assert;
diag_log "[ARC][SECURITY_FLOW] ALL_PASS";
'''
    for name, counter in [('tocRequestResetAll','tocResetCalls'),('tocRequestSave','tocSaveCalls'),('tocRequestRebuildActive','tocRebuildCalls')]:
        source = (ROOT / f'functions/core/fn_{name}.sqf').read_text(encoding='utf-8-sig')
        for mutant in [False, True]:
            body = lose_result_guard(source) if mutant else source
            fixture = header + '\nARC_FLOW_underTest = {\n' + model_engine(body) + '\n};\n'
            fixture += f'ARC_FLOW_counter = "ARC_TEST_{counter}";\n' + cases
            with tempfile.TemporaryDirectory(prefix='farabad-security-') as directory:
                path = Path(directory) / 'scope.sqf'
                path.write_text(fixture, encoding='utf-8')
                run = subprocess.run([str(executable), '--automated','--suppress-welcome','--no-execute-print','--input-sqf',str(path)], capture_output=True, text=True, timeout=30)
            output = run.stdout + run.stderr
            passed = '[ARC][SECURITY_FLOW] ALL_PASS' in output and '[ERR]' not in output and '[FAT]' not in output
            assert passed != mutant, f'{name} mutant={mutant}\n{output}'
        print(f'PASS: {name}: six production-body cases; removed-result-guard mutant rejected')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--sqfvm', type=Path)
    args = parser.parse_args()
    static_checks()
    if args.sqfvm:
        vm_checks(args.sqfvm.resolve())
        rtb_vm_checks(args.sqfvm.resolve())
    else:
        print('SKIP: VM production-body cases (provide --sqfvm). Arma MP acceptance remains BLOCKED.')
