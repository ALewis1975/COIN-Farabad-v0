/*
    ARC_fnc_threatFacilitatorNode

    Threat Economy v0: identify a facilitator node (safehouse, staging area, or courier route)
    and create a RAID_SAFEHOUSE follow-on task.

    Requires suspectedActor.confidence >= 0.6.

    Params:
      0: STRING threatId
      1: STRING nodeType ("SAFEHOUSE","STAGING_AREA","COURIER_ROUTE")

    Returns:
      BOOL (true if node was identified and task created)
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", "", [""]],
    ["_nodeType", "SAFEHOUSE", [""]]
];

if (_threatId isEqualTo "") exitWith {false};

private _nodeTypeU = toUpper _nodeType;

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

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// Load threat record
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

// Confidence gate
private _actor      = [_rec, "suspectedActor", []] call _kvGet;
private _confidence = [_actor, "confidence", 0.0] call _kvGet;
if (!(_confidence isEqualType 0)) then { _confidence = 0.0; };
if (_confidence < 0.6) exitWith
{
    diag_log format ["[ARC][INFO] ARC_fnc_threatFacilitatorNode: confidence=%1 < 0.6 threat=%2", _confidence, _threatId];
    false
};

// Determine node position
private _links      = [_rec, "links", []] call _kvGet;
private _area       = [_rec, "area", []] call _kvGet;
private _districtId = [_links, "district_id", "D00"] call _kvGet;
private _taskId     = [_links, "task_id", ""] call _kvGet;
private _pos        = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || {(count _pos) < 2}) then { _pos = [0,0,0]; };
_pos resize 3;

// Pick node position: isolated building for SAFEHOUSE, jitter for others
private _nodePos = _pos;
if (_nodeTypeU isEqualTo "SAFEHOUSE") then
{
    private _buildings = nearestObjects [_pos, ["Building"], 400];
    private _isolated = _buildings select { (_x distance2D _pos) > 80 };
    if ((count _isolated) > 0) then
    {
        _nodePos = getPosATL (_isolated select (floor (random (count _isolated))));
    }
    else
    {
        private _dir = random 360;
        _nodePos = [_pos select 0 + 50 * sin _dir, _pos select 1 + 50 * cos _dir, 0];
    };
}
else
{
    private _dir = random 360;
    private _dist = 30 + (random 120);
    _nodePos = [_pos select 0 + _dist * sin _dir, _pos select 1 + _dist * cos _dir, 0];
};
_nodePos resize 3;

// Node store key
private _nodeKey = format ["NODE:%1:%2", _threatId, _nodeTypeU];

// Load existing node store
private _nodeStore = ["threat_v0_node_store", createHashMap] call ARC_fnc_stateGet;
if (!(_nodeStore isEqualType createHashMap)) then { _nodeStore = createHashMap; };

// Check if node already exists
if (_nodeKey in _nodeStore) exitWith
{
    diag_log format ["[ARC][INFO] ARC_fnc_threatFacilitatorNode: node already exists key=%1", _nodeKey];
    false
};

// Build node record
private _nodeRecord = createHashMap;
_nodeRecord set ["nodeId",     _nodeKey];
_nodeRecord set ["threatId",   _threatId];
_nodeRecord set ["nodeType",   _nodeTypeU];
_nodeRecord set ["pos",        _nodePos];
_nodeRecord set ["created_ts", serverTime];

_nodeStore set [_nodeKey, _nodeRecord];
["threat_v0_node_store", _nodeStore] call ARC_fnc_stateSet;

// Emit facilitator node lead
private _nodeLeadId = [
    "IED",
    format ["%1 — %2", _nodeTypeU, _districtId],
    _nodePos,
    _confidence,
    7200,
    _taskId,
    "IED",
    "",
    "facilitator_node_lead"
] call ARC_fnc_leadCreate;

// Create RAID_SAFEHOUSE task via follow-on gate
private _raidTaskId = format ["RAID_SAFEHOUSE_%1_%2", _threatId, floor serverTime];
private _raidName   = format ["Raid Safehouse — %1", _districtId];

// Check follow-on cap before creating task
private _taskingOutputs = [_rec, "taskingOutputs", []] call _kvGet;
if (!(_taskingOutputs isEqualType [])) then { _taskingOutputs = []; };
private _existingTaskIds = [_taskingOutputs, "taskIds", []] call _kvGet;
if (!(_existingTaskIds isEqualType [])) then { _existingTaskIds = []; };

private _maxFollowOn = missionNamespace getVariable ["ARC_threatMaxFollowOnTasks", 1];
if (!(_maxFollowOn isEqualType 0)) then { _maxFollowOn = 1; };

private _taskCreated = false;
if ((count _existingTaskIds) < _maxFollowOn) then
{
    [_raidTaskId, "", _raidName, "RAID_SAFEHOUSE", _nodePos, ""] call ARC_fnc_taskCreateIncident;
    _existingTaskIds pushBack _raidTaskId;
    _taskingOutputs = [_taskingOutputs, "taskIds", _existingTaskIds] call _kvSet;
    _rec = [_rec, "taskingOutputs", _taskingOutputs] call _kvSet;
    _records set [_idxRec, _rec];
    ["threat_v0_records", _records] call ARC_fnc_stateSet;
    _taskCreated = true;
    diag_log format ["[ARC][INFO] ARC_fnc_threatFacilitatorNode: raid task created taskId=%1 threat=%2", _raidTaskId, _threatId];
};

diag_log format ["[ARC][INFO] ARC_fnc_threatFacilitatorNode: node=%1 lead=%2 taskCreated=%3 threat=%4", _nodeKey, _nodeLeadId, _taskCreated, _threatId];

true
