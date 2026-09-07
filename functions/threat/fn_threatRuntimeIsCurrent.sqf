/* Server-only identity guard for delayed/active threat execution; no writes. */
if (!isServer) exitWith {false};
params [["_taskId", "", [""]], ["_threatId", "", [""]], ["_kinds", [], [[]]]];
if (_taskId isEqualTo "" || { _threatId isEqualTo "" }) exitWith {false};
if !((["activeTaskId", ""] call ARC_fnc_stateGet) isEqualTo _taskId) exitWith {false};
if !((["activeIedThreatId", ""] call ARC_fnc_stateGet) isEqualTo _threatId) exitWith {false};
if !(["activeIncidentAccepted", false] call ARC_fnc_stateGet) exitWith {false};
if (["activeIncidentCloseReady", false] call ARC_fnc_stateGet) exitWith {false};
if !((toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet)) in _kinds) exitWith {false};
private _get = {
    params ["_pairs", "_key", "_default"];
    private _out = _default;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _record = [];
{
    if (([_x, "threat_id", ""] call _get) isEqualTo _threatId) exitWith { _record = _x; };
} forEach (["threat_v0_records", []] call ARC_fnc_stateGet);
private _links = [_record, "links", []] call _get;
(([_links, "task_id", ""] call _get) isEqualTo _taskId)
&& { (toUpper ([_record, "state", ""] call _get)) in ["CREATED", "ACTIVE", "STAGED", "DISCOVERED"] }
