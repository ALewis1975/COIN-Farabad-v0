/*
    ARC_fnc_threatApplyCoinInfluence

    Threat Economy v0: apply CIVSUB influence delta based on threat outcome.
    Called from ARC_fnc_threatUpdateState on DETONATED and NEUTRALIZED transitions.

    Guard: influence.applied flag prevents double-application.

    Params:
      0: STRING threatId

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", "", [""]]
];

if (_threatId isEqualTo "") exitWith {false};

if (!(missionNamespace getVariable ["civsub_v1_enabled", false])) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatApplyCoinInfluence: CIVSUB offline, skipping threat=%1", _threatId];
    false
};

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

// Load record
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

// Guard: prevent double-apply
private _influence = [_rec, "influence", []] call _kvGet;
if (!(_influence isEqualType [])) then { _influence = []; };
private _applied = [_influence, "applied", false] call _kvGet;
if (_applied isEqualType true && { _applied }) exitWith
{
    diag_log format ["[ARC][INFO] ARC_fnc_threatApplyCoinInfluence: already applied, skipping threat=%1", _threatId];
    false
};

// Determine outcome from state
private _stateU = toUpper ([_rec, "state", ""] call _kvGet);
private _outcomeResult = [_rec, "outcome", []] call _kvGet;
if (!(_outcomeResult isEqualType [])) then { _outcomeResult = []; };
private _result = toUpper ([_outcomeResult, "result", "OTHER"] call _kvGet);

// Resolve outcome category
private _outcomeCat = "OTHER";
if (_stateU isEqualTo "NEUTRALIZED") then { _outcomeCat = "DEFUSED"; };
if (_stateU isEqualTo "DETONATED")   then { _outcomeCat = "DETONATED"; };
if (_result isEqualTo "DRIVER_DETAINED") then { _outcomeCat = "DRIVER_DETAINED"; };

// Map to CIVSUB event
private _civEvent = "";
if (_outcomeCat isEqualTo "DEFUSED")          then { _civEvent = "IED_DEFUSED"; };
if (_outcomeCat isEqualTo "DETONATED")        then { _civEvent = "IED_DETONATED"; };
if (_outcomeCat isEqualTo "DRIVER_DETAINED")  then { _civEvent = "IED_DRIVER_DETAINED"; };

private _links = [_rec, "links", []] call _kvGet;
private _districtId = [_links, "district_id", "D00"] call _kvGet;

if (!(_civEvent isEqualTo "")) then
{
    [_districtId, _civEvent, "THREAT_ECONOMY", createHashMap, ""] call ARC_fnc_civsubEmitDelta;
    diag_log format ["[ARC][INFO] ARC_fnc_threatApplyCoinInfluence: event=%1 district=%2 threat=%3", _civEvent, _districtId, _threatId];
};

// Mark applied
_influence = [_influence, "applied", true] call _kvSet;
_influence = [_influence, "appliedAt", serverTime] call _kvSet;
_influence = [_influence, "outcomeCat", _outcomeCat] call _kvSet;
_rec = [_rec, "influence", _influence] call _kvSet;

_records set [_idxRec, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;

true
