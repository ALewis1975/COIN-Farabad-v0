/*
 Opt-in dedicated-server data regression harness. Requires idle task state and
 ARC_criticalRepairTestsEnabled=true. Execute with execVM after mission startup.
 Runs actual state/identity/maintenance/transition helpers; restores state and
 published threat test snapshots. It never creates explosives or world actors.
 The Python runner executes the same assertions in SQF-VM with documented host
 adapters, which does not establish Arma multiplayer/runtime correctness.
*/
if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["ARC_criticalRepairTestsEnabled",false]) exitWith {false};
if !((["activeTaskId",""] call ARC_fnc_stateGet) isEqualTo "") exitWith {false};
if (serverTime < 2) exitWith {false};
private _failures = 0;
private _passes = 0;
private _assert = {
    params ["_ok","_name"];
    if (_ok) then {_passes = _passes + 1} else {_failures = _failures + 1};
    diag_log format ["[ARC][TEST][THREAT] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_name];
};
// Unscheduled atomic fixture block prevents scheduled campaign ticks interleaving.
isNil {
    private _saved = [];
    {
        _saved pushBack [_x,isNil {missionNamespace getVariable _x},missionNamespace getVariable [_x,[]]];
    } forEach ["ARC_state","ARC_stateWriteGen","threat_v0_debug_counts","threat_v0_debug_open","threat_v0_debug_last_event","threat_v0_events_public","ARC_threatLatentTtlS"];
    try {
        missionNamespace setVariable ["ARC_state",[]];
        missionNamespace setVariable ["ARC_threatLatentTtlS",300];
        private _get = {
            params ["_pairs","_key","_fallback"];
            private _i = -1;
            { if ((_x select 0) isEqualTo _key) exitWith { _i = _forEachIndex; }; } forEach _pairs;
            if (_i < 0) exitWith {_fallback};
            (_pairs select _i) select 1
        };
        private _fixture = {
            params ["_id","_state",["_task",""],["_type","IED"],["_created",-10000]];
            [["v",0],["threat_id",_id],["type",_type],["family",_type],["state",_state],["rev",1],["created_ts",_created],["updated_ts",_created],["links",[["task_id",_task],["incident_id",""],["district_id","D01"]]],["classification",[["budget_cost",1]]],["world",[["spawned",false],["objects_net_ids",[]],["units_net_ids",[]],["groups_net_ids",[]]]],["area",[["pos",[0,0,0]],["grid","000000"]]]]
        };
        private _readRec = {
            params ["_id"];
            private _bank = ["threat_v0_records",[]] call ARC_fnc_stateGet;
            private _i = -1;
            { if (([_x,"threat_id",""] call _get) isEqualTo _id) exitWith { _i = _forEachIndex; }; } forEach _bank;
            if (_i < 0) exitWith {[]};
            _bank select _i
        };
        ["activeTaskId","TASK-A"] call ARC_fnc_stateSet;
        ["activeIedThreatId","THR:A"] call ARC_fnc_stateSet;
        ["activeIncidentAccepted",true] call ARC_fnc_stateSet;
        ["activeIncidentCloseReady",false] call ARC_fnc_stateSet;
        ["activeObjectiveKind","VBIED_DRIVEN_GATE"] call ARC_fnc_stateSet;
        ["threat_v0_records",[["THR:A","STAGED","TASK-A","VBIED"] call _fixture]] call ARC_fnc_stateSet;
        private _args = ["TASK-A","THR:A",["VBIED_DRIVEN_GATE"]];
        [_args call ARC_fnc_threatRuntimeIsCurrent,"matching staged owner accepted"] call _assert;
        [!(["TASK-B","THR:A",["VBIED_DRIVEN_GATE"]] call ARC_fnc_threatRuntimeIsCurrent),"same-kind replacement task rejected"] call _assert;
        [!(["TASK-A","THR:B",["VBIED_DRIVEN_GATE"]] call ARC_fnc_threatRuntimeIsCurrent),"replacement threat rejected"] call _assert;
        ["activeIncidentCloseReady",true] call ARC_fnc_stateSet;
        [!(_args call ARC_fnc_threatRuntimeIsCurrent),"closure cancels monitor identity"] call _assert;
        ["activeIncidentCloseReady",false] call ARC_fnc_stateSet;
        ["activeIncidentAccepted",false] call ARC_fnc_stateSet;
        [!(_args call ARC_fnc_threatRuntimeIsCurrent),"unaccepted incident rejected"] call _assert;
        ["activeIncidentAccepted",true] call ARC_fnc_stateSet;
        ["threat_v0_records",[["THR:A","EXPIRED","TASK-A","VBIED"] call _fixture]] call ARC_fnc_stateSet;
        [!(_args call ARC_fnc_threatRuntimeIsCurrent),"expired record cannot revive"] call _assert;

        ["activeTaskId",""] call ARC_fnc_stateSet;
        ["activeIedThreatId",""] call ARC_fnc_stateSet;
        private _old = ["THR:OLD","CREATED"] call _fixture;
        private _future = ["THR:FUTURE","CREATED","","IED",serverTime] call _fixture;
        private _linked = ["THR:LINKED","CREATED","TASK-LINKED"] call _fixture;
        private _virtual = ["VPOOL:1","VIRTUAL_DORMANT","","VIRTUAL_OPFOR"] call _fixture;
        ["threat_v0_records",[_old,_future,_linked,_virtual]] call ARC_fnc_stateSet;
        ["threat_v0_open_index",["THR:OLD","THR:FUTURE","THR:LINKED"]] call ARC_fnc_stateSet;
        private _result = [] call ARC_fnc_threatMaintenanceTick;
        [(_result select 0) isEqualTo 1,"exactly one due latent record retired"] call _assert;
        private _oldNow = ["THR:OLD"] call _readRec;
        [([_oldNow,"state",""] call _get) isEqualTo "CLEANED","legacy negative creation age converges CLEANED"] call _assert;
        [! ("THR:OLD" in (["threat_v0_open_index",[]] call ARC_fnc_stateGet)),"expired district reservation released"] call _assert;
        [([[_oldNow,"world",[]] call _get,"cleanup_completed",false] call _get),"cleanup completion committed"] call _assert;
        [([(["THR:FUTURE"] call _readRec),"state",""] call _get) isEqualTo "CREATED","future deadline preserved"] call _assert;
        [([(["THR:LINKED"] call _readRec),"state",""] call _get) isEqualTo "CREATED","task-linked record preserved"] call _assert;
        [([(["VPOOL:1"] call _readRec),"state",""] call _get) isEqualTo "VIRTUAL_DORMANT","virtual pool preserved"] call _assert;
        private _rev = [_oldNow,"rev",0] call _get;
        ["THR:OLD","TEST_REPEAT"] call ARC_fnc_threatIedCleanupSync;
        [([(["THR:OLD"] call _readRec),"rev",0] call _get) isEqualTo _rev,"repeated cleanup is idempotent"] call _assert;

        private _bank = [];
        for "_i" from 0 to 59 do {_bank pushBack ([format ["THR:H%1",_i],"CLEANED","","IED",_i] call _fixture)};
        _bank pushBack (["THR:PROTECTED","CLEANED"] call _fixture);
        _bank pushBack _virtual;
        ["threat_v0_records",_bank] call ARC_fnc_stateSet;
        ["threat_v0_open_index",[]] call ARC_fnc_stateSet;
        ["threat_v0_closed_max",50] call ARC_fnc_stateSet;
        ["leadPool",[["meta",[["threat_id","THR:PROTECTED"]]]]] call ARC_fnc_stateSet;
        _result = [] call ARC_fnc_threatMaintenanceTick;
        [(_result select 1) isEqualTo 10,"prune oldest ten excess ordinary records"] call _assert;
        [(count (["threat_v0_records",[]] call ARC_fnc_stateGet)) isEqualTo 52,"bounded history plus protected/virtual records retained"] call _assert;
        [!((["THR:PROTECTED"] call _readRec) isEqualTo []),"nested lead consumer reference protected"] call _assert;
        [(["THR:H0"] call _readRec) isEqualTo [],"oldest eligible record pruned"] call _assert;
        [!((["THR:H59"] call _readRec) isEqualTo []),"newest eligible record kept"] call _assert;
    } catch {
        [false,format ["exception: %1",_exception]] call _assert;
    };
    {
        _x params ["_key","_absent","_value"];
        missionNamespace setVariable [_key,if (_absent) then {nil} else {_value},_key isEqualTo "threat_v0_events_public"];
    } forEach _saved;
};
diag_log format ["[ARC][TEST][THREAT] SUMMARY pass=%1 fail=%2",_passes,_failures];
_failures isEqualTo 0
