/*
    ARC_fnc_threatScheduleEvent

    Threat Economy v0: schedule a new standalone threat record for a district.
    Called by ARC_fnc_threatSchedulerTick when the governor clears a district.

    Creates a ThreatRecord in the threat_v0_records bank and emits an IED Warning Lead.
    If a convoy is currently active on the MSR, the threat targets the convoy route;
    otherwise it targets a generic FOOT_PATROL pattern within the district.

    Downstream spawn ticks (fn_iedSpawnTick, fn_vbiedSpawnTick, etc.) handle
    actual world instantiation based on the active objective kind.

    Params:
      0: STRING districtId
      1: NUMBER escalationTier (0..n)

    Returns:
      BOOL (true = record scheduled, false = skipped/error)
*/

if (!isServer) exitWith {false};

params [
    ["_districtId", "", [""]],
    ["_tier", 0, [0]]
];

if (_districtId isEqualTo "") exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

// ---------------------------------------------------------------------------
// Helper: pairs-array get/set (mirrors fn_threatCreateFromTask convention)
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Campaign ID + sequence
// ---------------------------------------------------------------------------
private _campaignId = ["threat_v0_campaign_id", ""] call ARC_fnc_stateGet;
if (!(_campaignId isEqualType "") || { _campaignId isEqualTo "" }) then
{
    _campaignId = if (!isNil "BIS_fnc_guid") then { call BIS_fnc_guid } else { format ["CID-%1-%2", diag_tickTime, floor (random 1e6)] };
    ["threat_v0_campaign_id", _campaignId] call ARC_fnc_stateSet;
};

private _seq = ["threat_v0_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
_seq = _seq + 1;
["threat_v0_seq", _seq] call ARC_fnc_stateSet;

private _s = str _seq;
private _zeros = "000000";
private _need = (6 - (count _s)) max 0;
private _seq6 = (_zeros select [0, _need]) + _s;

private _threatId = format ["THR:%1:%2", _districtId, _seq6];

// ---------------------------------------------------------------------------
// MSR/Convoy-aware target selection (T10 integration)
// ---------------------------------------------------------------------------
// If a convoy is active and has route points, target the convoy on its MSR route.
// Otherwise, fall back to a generic FOOT_PATROL target within the district.
// ---------------------------------------------------------------------------
private _convoyNetIds = missionNamespace getVariable ["ARC_activeConvoyNetIds", []];
if (!(_convoyNetIds isEqualType [])) then { _convoyNetIds = []; };
private _convoyActive = (count _convoyNetIds) > 0;

private _targetProfile = "FOOT_PATROL";
private _basePos = [];

if (_convoyActive) then
{
    _targetProfile = "CONVOY";

    private _routePts = ["activeConvoyRoutePoints", []] call ARC_fnc_stateGet;
    if (!(_routePts isEqualType [])) then { _routePts = []; };

    if ((count _routePts) > 1) then
    {
        // Pick a point between 30 % and 70 % along the route (threat placed mid-route).
        private _startIdx = floor (0.30 * (count _routePts));
        private _endIdx   = floor (0.70 * (count _routePts));
        if (_endIdx <= _startIdx) then { _endIdx = _startIdx + 1; };
        _endIdx = _endIdx min ((count _routePts) - 1);
        private _idx = _startIdx + floor (random ((_endIdx - _startIdx) + 1));
        _idx = _idx min ((count _routePts) - 1);
        _basePos = _routePts select _idx;
    };

    if (_basePos isEqualTo [] || { (count _basePos) < 2 }) then
    {
        // Route not available - use lead vehicle position.
        private _leadNid = _convoyNetIds select 0;
        private _leadVeh = objectFromNetId _leadNid;
        if (!isNull _leadVeh) then { _basePos = getPosATL _leadVeh; };
    };
};

// Fallback: use active incident position or origin marker.
if (_basePos isEqualTo [] || { (count _basePos) < 2 }) then
{
    _basePos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
    if (!(_basePos isEqualType []) || { (count _basePos) < 2 }) then { _basePos = []; };
};

// Last-resort: use district objective marker (named district_<id>_obj or similar).
if (_basePos isEqualTo [] || { (count _basePos) < 2 }) then
{
    private _mk = format ["district_%1_obj", toLower _districtId];
    if (_mk in allMapMarkers) then { _basePos = getMarkerPos _mk; };
};

if (_basePos isEqualTo [] || { (count _basePos) < 2 }) then
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatScheduleEvent: no base position for district=%1 - skipping", _districtId];
    exitWith {false};
};

_basePos = +_basePos; _basePos resize 3; _basePos set [2, 0];

// ---------------------------------------------------------------------------
// Pick a roadside IED site near the base position
// ---------------------------------------------------------------------------
private _iedPos = [_basePos] call ARC_fnc_iedPickSite;
if (_iedPos isEqualTo [] || { (count _iedPos) < 2 }) then { _iedPos = _basePos; };

// ---------------------------------------------------------------------------
// Build ThreatRecord (pairs-array format)
// ---------------------------------------------------------------------------
private _now = serverTime;

private _area = [];
_area = [_area, "pos", _iedPos] call _kvSet;
_area = [_area, "grid", mapGridPosition _iedPos] call _kvSet;
_area = [_area, "radius_m", 80] call _kvSet;
_area = [_area, "despawn_m", 600] call _kvSet;

private _links = [];
_links = [_links, "district_id", _districtId] call _kvSet;
_links = [_links, "task_id", ""] call _kvSet;
_links = [_links, "target_profile", _targetProfile] call _kvSet;

private _classification = [];
_classification = [_classification, "type", "IED"] call _kvSet;
_classification = [_classification, "subtype", "IED_EMPLACED_SINGLE"] call _kvSet;
_classification = [_classification, "escalation_tier", _tier] call _kvSet;
_classification = [_classification, "priority", ((_tier min 4) + 1)] call _kvSet;

private _world = [];
_world = [_world, "spawned", false] call _kvSet;
_world = [_world, "objects_net_ids", []] call _kvSet;
_world = [_world, "groups_net_ids", []] call _kvSet;
_world = [_world, "units_net_ids", []] call _kvSet;

private _stateTsNew = [];
_stateTsNew = [_stateTsNew, "planned", _now] call _kvSet;

private _audit = [];
_audit = [_audit, "created_at", _now] call _kvSet;
_audit = [_audit, "created_by", "SYSTEM"] call _kvSet;
_audit = [_audit, "last_updated_at", _now] call _kvSet;

private _rec = [];
_rec = [_rec, "threat_id", _threatId] call _kvSet;
_rec = [_rec, "links", _links] call _kvSet;
_rec = [_rec, "area", _area] call _kvSet;
_rec = [_rec, "classification", _classification] call _kvSet;
_rec = [_rec, "world", _world] call _kvSet;
_rec = [_rec, "state", "PLANNED"] call _kvSet;
_rec = [_rec, "state_ts", _stateTsNew] call _kvSet;
_rec = [_rec, "audit", _audit] call _kvSet;
_rec = [_rec, "rev", 1] call _kvSet;

// ---------------------------------------------------------------------------
// Persist record and update open index
// ---------------------------------------------------------------------------
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };
_records pushBack _rec;
["threat_v0_records", _records] call ARC_fnc_stateSet;

private _open = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
if (!(_open isEqualType [])) then { _open = []; };
_open pushBackUnique _threatId;
["threat_v0_open_index", _open] call ARC_fnc_stateSet;

diag_log format [
    "[ARC][THREAT] ARC_fnc_threatScheduleEvent: scheduled threat_id=%1 district=%2 tier=%3 target=%4 pos=%5",
    _threatId, _districtId, _tier, _targetProfile, _iedPos
];

// ---------------------------------------------------------------------------
// Emit IED Warning Lead (gives players a first intel cue about the threat)
// ---------------------------------------------------------------------------
[_rec, "DISCOVERED"] call ARC_fnc_iedEmitLeads;

true
