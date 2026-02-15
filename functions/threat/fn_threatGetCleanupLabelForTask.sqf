/*
    Threat helper: get (and ensure) cleanup label for a threat linked to a task.

    Params:
        0: STRING task_id

    Returns:
        STRING cleanup_label ("" if none)
*/

if (!isServer) exitWith {""};

params [["_taskId", ""]];
if (_taskId isEqualTo "") exitWith {""};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {""};

// Small helpers for "pairs arrays"
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _key } };
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs # _idx) # 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _kvSet = {
    params ["_pairs", "_key", "_value"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _key } };
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) exitWith {""};

private _idxRec = _records findIf {
    private _rec = _x;
    private _links = [_rec, "links", []] call _kvGet;
    ([_links, "task_id", ""] call _kvGet) isEqualTo _taskId
};

if (_idxRec < 0) exitWith {""};

private _rec = _records # _idxRec;
private _tid = [_rec, "threat_id", ""] call _kvGet;
if (_tid isEqualTo "") exitWith {""};

private _type = [_rec, "type", "OTHER"] call _kvGet;
if (!(_type isEqualType "")) then { _type = "OTHER"; };

private _world = [_rec, "world", []] call _kvGet;

private _label = [_world, "cleanup_label", ""] call _kvGet;
if (!(_label isEqualType "")) then { _label = ""; };

private _want = format ["THREAT:%1:%2", toUpper _type, _tid];

if (_label isEqualTo "") then
{
    _label = _want;
    _world = [_world, "cleanup_label", _label] call _kvSet;
    _rec = [_rec, "world", _world] call _kvSet;
    _records set [_idxRec, _rec];
    ["threat_v0_records", _records] call ARC_fnc_stateSet;
}
else
{
    // Normalize if needed
    if (_label isNotEqualTo _want) then
    {
        _label = _want;
        _world = [_world, "cleanup_label", _label] call _kvSet;
        _rec = [_rec, "world", _world] call _kvSet;
        _records set [_idxRec, _rec];
        ["threat_v0_records", _records] call ARC_fnc_stateSet;
    };
};

_label
