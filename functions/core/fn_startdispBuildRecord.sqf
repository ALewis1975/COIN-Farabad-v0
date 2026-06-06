/* Build a serialized STARTDISP v1 record. */
if (!isServer) exitWith { [] };

params [
    ["_caller", objNull],
    ["_capture", [], [[]]],
    ["_lace", [], [[]]],
    ["_deficiencies", "", [""]],
    ["_additionalRequested", false, [false]],
    ["_additionalNotes", "", [""]]
];
if (isNull _caller) exitWith { [] };
private _trimFn = compile "params ['_s']; trim _s";

private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    if (_pairs isEqualType []) then
    {
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    };
    _out
};
private _enumLace = {
    params ["_v"];
    if (!(_v isEqualType "")) then { _v = "GREEN"; };
    _v = toUpper ([_v] call _trimFn);
    if !(_v in ["GREEN", "AMBER", "RED"]) then { _v = "GREEN"; };
    _v
};
private _laceVal = {
    params ["_pairs", "_key", "_def"];
    private _v = [_pairs, _key, _def] call _get;
    [_v] call _enumLace
};

private _seq = ["startdisp_v1_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
_seq = _seq + 1;
["startdisp_v1_seq", _seq] call ARC_fnc_stateSet;

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _district = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if (!(_district isEqualType "") || { _district isEqualTo "" }) then { _district = "D00"; };
private _seqStr = str _seq;
while { (count _seqStr) < 6 } do { _seqStr = "0" + _seqStr; };
private _sid = format ["SDISP:%1:%2", _district, _seqStr];

private _uid = getPlayerUID _caller;
private _grp = group _caller;
private _gid = if (isNull _grp) then { "" } else { groupId _grp };
private _role = if (isNil "ARC_fnc_rolesGetTag") then { "" } else { [_caller] call ARC_fnc_rolesGetTag };

private _defText = [_deficiencies] call _trimFn;
if ((count _defText) > 500) then { _defText = _defText select [0, 500]; };
private _addText = [_additionalNotes] call _trimFn;
if ((count _addText) > 500) then { _addText = _addText select [0, 500]; };
private _defs = if (_defText isEqualTo "") then { [] } else { [_defText] };

[
    ["v", 1],
    ["startdisp_id", _sid],
    ["task_id", _taskId],
    ["district_id", _district],
    ["created_ts", serverTime],
    ["created_by_uid", _uid],
    ["created_by_name", name _caller],
    ["created_by_group", _gid],
    ["created_by_role", _role],
    ["capture_pos", [_capture, "capture_pos", getPosATL _caller] call _get],
    ["capture_grid", [_capture, "capture_grid", mapGridPosition _caller] call _get],
    ["personnel", [_capture, "personnel", []] call _get],
    ["vehicles", [_capture, "vehicles", [["count", 0], ["records", []]]] call _get],
    ["equipment", [_capture, "equipment", []] call _get],
    ["ammo", [_capture, "ammo", []] call _get],
    ["lace", [["liquids", [_lace, "liquids", "GREEN"] call _laceVal], ["ammo", [_lace, "ammo", "GREEN"] call _laceVal], ["casualties", [_lace, "casualties", "GREEN"] call _laceVal], ["equipment", [_lace, "equipment", "GREEN"] call _laceVal], ["overall", [_lace, "overall", "GREEN"] call _laceVal]]],
    ["leader_notes", ""],
    ["deficiencies", _defs],
    ["additional_supplies_requested", _additionalRequested],
    ["additional_supply_notes", _addText]
]
