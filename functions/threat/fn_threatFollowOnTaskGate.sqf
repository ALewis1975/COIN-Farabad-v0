/*
    ARC_fnc_threatFollowOnTaskGate

    Threat Economy v0: create a FACILITATOR_HUNT follow-on task if under cap.
    Called from ARC_fnc_threatAttributionUpdate when confidence >= 0.5.

    Params:
      0: STRING threatId

    Returns:
      BOOL (true if task was created)
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", "", [""]]
];

if (_threatId isEqualTo "") exitWith {false};

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs select _idx) select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _kvSet = {
    params ["_pairs", "_key", "_value"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) exitWith {false};

private _idxRec = -1;
{
    private _tid = "";
    { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "threat_id"}) exitWith { _tid = _x select 1; }; } forEach _x;
    if (_tid isEqualTo _threatId) exitWith { _idxRec = _forEachIndex; };
} forEach _records;

if (_idxRec < 0) exitWith {false};

private _rec = _records select _idxRec;

// Load or create taskingOutputs sub-record
private _taskingOutputs = [_rec, "taskingOutputs", []] call _kvGet;
if (!(_taskingOutputs isEqualType [])) then { _taskingOutputs = []; };

private _existingTaskIds = [_taskingOutputs, "taskIds", []] call _kvGet;
if (!(_existingTaskIds isEqualType [])) then { _existingTaskIds = []; };

// Governor cap
private _maxFollowOn = missionNamespace getVariable ["ARC_threatMaxFollowOnTasks", 1];
if (!(_maxFollowOn isEqualType 0)) then { _maxFollowOn = 1; };

if ((count _existingTaskIds) >= _maxFollowOn) exitWith
{
    diag_log format ["[ARC][INFO] ARC_fnc_threatFollowOnTaskGate: cap reached (%1) threat=%2", count _existingTaskIds, _threatId];
    false
};

// Determine task position
private _links = [_rec, "links", []] call _kvGet;
private _area  = [_rec, "area", []] call _kvGet;
private _districtId = [_links, "district_id", "D00"] call _kvGet;
private _pos = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || {(count _pos) < 2}) then { _pos = [0,0,0]; };
_pos resize 3;

// Try safehouse node position from cellLink
private _cellLink = [_rec, "cellLink", []] call _kvGet;
private _safeNodeId = [_cellLink, "safehouseNodeId", ""] call _kvGet;
if (!(_safeNodeId isEqualTo "") && { _safeNodeId in allMapMarkers }) then
{
    _pos = getMarkerPos _safeNodeId;
};

// Create follow-on task
private _followOnTaskId = format ["FACILITATOR_HUNT_%1_%2", _threatId, floor serverTime];
private _displayName    = format ["Facilitator Hunt — %1", _districtId];

[_followOnTaskId, "", _displayName, "FACILITATOR_HUNT", _pos, ""] call ARC_fnc_taskCreateIncident;

// Append task ID to record
_existingTaskIds pushBack _followOnTaskId;
_taskingOutputs = [_taskingOutputs, "taskIds", _existingTaskIds] call _kvSet;
_taskingOutputs = [_taskingOutputs, "sitrepRequired", true] call _kvSet;
_rec = [_rec, "taskingOutputs", _taskingOutputs] call _kvSet;

_records set [_idxRec, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;

diag_log format ["[ARC][INFO] ARC_fnc_threatFollowOnTaskGate: created taskId=%1 threat=%2", _followOnTaskId, _threatId];

true
