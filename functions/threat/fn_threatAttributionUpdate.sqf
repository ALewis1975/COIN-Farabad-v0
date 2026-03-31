/*
    ARC_fnc_threatAttributionUpdate

    Threat Economy v0: update suspected actor confidence for a threat record.
    Emits high-confidence attribution lead when confidence >= 0.8.

    Params:
      0: STRING threatId
      1: STRING evidenceType ("SSE","DETAINEE_STATEMENT","PATTERN_MATCH","SITREP_CONFIRMED")
      2: NUMBER confidenceDelta (0.0..1.0)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", "", [""]],
    ["_evidenceType", "SSE", [""]],
    ["_confidenceDelta", 0.1, [0]]
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

// Load or create suspectedActor sub-record
private _actor = [_rec, "suspectedActor", []] call _kvGet;
if (!(_actor isEqualType [])) then { _actor = []; };

private _confidence = [_actor, "confidence", 0.0] call _kvGet;
if (!(_confidence isEqualType 0)) then { _confidence = 0.0; };

private _prevConfidence = _confidence;
_confidence = (_confidence + _confidenceDelta) max 0.0 min 1.0;

private _actorType = [_actor, "actorType", "UNKNOWN"] call _kvGet;

// Upgrade actorType when crossing 0.5
private _callsigns = ["COBRA","VIPER","ALPHA","UNKNOWN"];
if (_confidence >= 0.5 && { _prevConfidence < 0.5 }) then
{
    _actorType = "TIM_CELL";

    // Deterministic callsign from district + threat sequence
    private _links = [_rec, "links", []] call _kvGet;
    private _districtId = [_links, "district_id", "D00"] call _kvGet;
    private _seed = 0;
    private _cs = count _districtId;
    for "_i" from 0 to (_cs - 1) do { _seed = _seed + (toArray (_districtId select [_i,1]) select 0); };
    private _csIdx = _seed mod 3; // COBRA/VIPER/ALPHA
    private _callsign = _callsigns select _csIdx;

    _actor = [_actor, "callsign", _callsign] call _kvSet;
    diag_log format ["[ARC][INFO] ARC_fnc_threatAttributionUpdate: confidence>=0.5 actorType→TIM_CELL callsign=%1 threat=%2", _callsign, _threatId];
};

_actor = [_actor, "confidence", _confidence] call _kvSet;
_actor = [_actor, "actorType", _actorType] call _kvSet;

private _evHistory = [_actor, "evidenceHistory", []] call _kvGet;
if (!(_evHistory isEqualType [])) then { _evHistory = []; };
_evHistory pushBack [_evidenceType, _confidenceDelta, serverTime];
_actor = [_actor, "evidenceHistory", _evHistory] call _kvSet;

_rec = [_rec, "suspectedActor", _actor] call _kvSet;

// Emit high-confidence attribution lead when crossing 0.8
if (_confidence >= 0.8 && { _prevConfidence < 0.8 }) then
{
    private _links = [_rec, "links", []] call _kvGet;
    private _area  = [_rec, "area", []] call _kvGet;
    private _taskId = [_links, "task_id", ""] call _kvGet;
    private _districtId = [_links, "district_id", "D00"] call _kvGet;
    private _pos = [_area, "pos", [0,0,0]] call _kvGet;
    if (!(_pos isEqualType []) || {(count _pos) < 2}) then { _pos = [0,0,0]; };
    _pos resize 3;

    private _callsign = [_actor, "callsign", "UNKNOWN"] call _kvGet;
    private _attrId = [
        "IED",
        format ["Cell Identified: %1 — %2", _callsign, _districtId],
        _pos,
        0.8,
        7200,
        _taskId,
        "IED",
        "",
        "cell_id_lead"
    ] call ARC_fnc_leadCreate;

    diag_log format ["[ARC][INFO] ARC_fnc_threatAttributionUpdate: high-confidence cell_id_lead=%1 callsign=%2 threat=%3", _attrId, _callsign, _threatId];

    // Gate follow-on task
    if (!isNil "ARC_fnc_threatFollowOnTaskGate") then
    {
        [_threatId] call ARC_fnc_threatFollowOnTaskGate;
    };
};

// Write record back
_records set [_idxRec, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;

diag_log format ["[ARC][INFO] ARC_fnc_threatAttributionUpdate: threat=%1 evType=%2 delta=%3 confidence=%4→%5", _threatId, _evidenceType, _confidenceDelta, _prevConfidence, _confidence];

true
