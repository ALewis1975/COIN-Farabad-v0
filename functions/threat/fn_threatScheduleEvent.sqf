/*
    ARC_fnc_threatScheduleEvent

    Threat Economy v0: schedule a new standalone threat record for a district.
    Called by ARC_fnc_threatSchedulerTick when the governor clears a district.

    Creates a posture-driven ThreatRecord in the threat_v0_records bank and emits a lead.
    If a convoy is currently active on the MSR, the threat targets the convoy route;
    otherwise it targets a generic FOOT_PATROL pattern within the district.

    Downstream spawn ticks (fn_iedSpawnTick, fn_vbiedSpawnTick, etc.) handle
    actual world instantiation based on the active objective kind.

    Params:
      0: STRING districtId
      1: NUMBER escalationTier (0..n)
      2: STRING threatType (default "IED")
      3: STRING threatSubtype (default "IED_EMPLACED_SINGLE")
      4: NUMBER intelQuality (0..1, default derived from tier)
      5: NUMBER budgetCost (default 1)
      6: STRING district posture (default "NORMAL")
      7: STRING threat intent (default "IED_PRESSURE")

    Returns:
      BOOL (true = record scheduled, false = skipped/error)
*/

if (!isServer) exitWith {false};

params [
    ["_districtId", "", [""]],
    ["_tier", 0, [0]],
    ["_threatType", "IED", [""]],
    ["_threatSubtype", "IED_EMPLACED_SINGLE", [""]],
    ["_intelQuality", -1, [0]],
    ["_budgetCost", 1, [0]],
    ["_districtPosture", "NORMAL", [""]],
    ["_threatIntent", "IED_PRESSURE", [""]]
];

if (_districtId isEqualTo "") exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";
private _typeU = toUpper ([_threatType] call _trimFn);
if (_typeU isEqualTo "") then { _typeU = "IED"; };
private _subtypeU = toUpper ([_threatSubtype] call _trimFn);
if (_subtypeU isEqualTo "") then { _subtypeU = "IED_EMPLACED_SINGLE"; };
private _postureU = toUpper ([_districtPosture] call _trimFn);
if (!(_postureU in ["NORMAL", "ELEVATED", "HIGH_RISK", "CRITICAL"])) then { _postureU = "NORMAL"; };
private _intentU = toUpper ([_threatIntent] call _trimFn);
if (_intentU isEqualTo "") then { _intentU = "IED_PRESSURE"; };
if (!(_intelQuality isEqualType 0) || { _intelQuality < 0 }) then
{
    _intelQuality = switch (_postureU) do
    {
        case "CRITICAL": { 0.38 };
        case "HIGH_RISK": { 0.48 };
        case "ELEVATED": { 0.60 };
        default { 0.70 };
    };
};
_intelQuality = (_intelQuality max 0) min 1;
if (!(_budgetCost isEqualType 0) || { _budgetCost < 1 }) then { _budgetCost = 1; };
// Below this quality, leads remain recorded but omit extra telegraphing cues.
private _cueIntelMin = 0.35;
private _nonIedLeadTtlS = 2700;

// ---------------------------------------------------------------------------
// Helper: pairs-array set (mirrors fn_threatCreateFromTask convention)
// ---------------------------------------------------------------------------
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

if (_basePos isEqualTo [] || { (count _basePos) < 2 }) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatScheduleEvent: no base position for district=%1 - skipping", _districtId];
    false
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

private _familyU = [_typeU, _subtypeU] call ARC_fnc_threatInferFamily;

private _area = [];
_area = [_area, "pos", _iedPos] call _kvSet;
_area = [_area, "grid", mapGridPosition _iedPos] call _kvSet;
_area = [_area, "radius_m", 80] call _kvSet;
_area = [_area, "despawn_m", 600] call _kvSet;

private _links = [];
_links = [_links, "ao_id", ""] call _kvSet;
_links = [_links, "district_id_source", _districtId] call _kvSet;
_links = [_links, "district_id", _districtId] call _kvSet;
_links = [_links, "task_id", ""] call _kvSet;
_links = [_links, "lead_id", ""] call _kvSet;
_links = [_links, "incident_id", ""] call _kvSet;
_links = [_links, "target_profile", _targetProfile] call _kvSet;

private _classification = [];
_classification = [_classification, "type", _typeU] call _kvSet;
_classification = [_classification, "subtype", _subtypeU] call _kvSet;
_classification = [_classification, "escalation_tier", _tier] call _kvSet;
_classification = [_classification, "district_posture", _postureU] call _kvSet;
_classification = [_classification, "threat_intent", _intentU] call _kvSet;
_classification = [_classification, "budget_cost", _budgetCost] call _kvSet;
_classification = [_classification, "intel_quality", _intelQuality] call _kvSet;
_classification = [_classification, "priority", ((_tier min 4) + 1)] call _kvSet;

private _world = [];
_world = [_world, "spawned", false] call _kvSet;
_world = [_world, "objects_net_ids", []] call _kvSet;
_world = [_world, "groups_net_ids", []] call _kvSet;
_world = [_world, "units_net_ids", []] call _kvSet;
_world = [_world, "cleanup_label", ""] call _kvSet;

private _stateTsNew = [];
_stateTsNew = [_stateTsNew, "created", _now] call _kvSet;
_stateTsNew = [_stateTsNew, "active", -1] call _kvSet;
_stateTsNew = [_stateTsNew, "discovered", -1] call _kvSet;
_stateTsNew = [_stateTsNew, "neutralized", -1] call _kvSet;
_stateTsNew = [_stateTsNew, "closed", -1] call _kvSet;
_stateTsNew = [_stateTsNew, "cleaned", -1] call _kvSet;
_stateTsNew = [_stateTsNew, "expired", -1] call _kvSet;

private _tele = [];
// Keep legacy intel_level while adding explicit intel_quality for economy views.
_tele = [_tele, "intel_level", _intelQuality] call _kvSet;
_tele = [_tele, "intel_quality", _intelQuality] call _kvSet;
_tele = [_tele, "cues_enabled", _intelQuality >= _cueIntelMin] call _kvSet;

private _outcome = [];
_outcome = [_outcome, "result", "NONE"] call _kvSet;
_outcome = [_outcome, "notes", ""] call _kvSet;

private _audit = [];
_audit = [_audit, "created_by", "SYSTEM"] call _kvSet;
_audit = [_audit, "last_updated_by", "SYSTEM"] call _kvSet;
_audit = [_audit, "log_refs", []] call _kvSet;

private _rec = [];
_rec = [_rec, "v", 0] call _kvSet;
_rec = [_rec, "threat_id", _threatId] call _kvSet;
_rec = [_rec, "campaign_id", _campaignId] call _kvSet;
_rec = [_rec, "rev", 1] call _kvSet;
_rec = [_rec, "created_ts", _now] call _kvSet;
_rec = [_rec, "updated_ts", _now] call _kvSet;
_rec = [_rec, "family", _familyU] call _kvSet;
_rec = [_rec, "type", _typeU] call _kvSet;
_rec = [_rec, "subtype", _subtypeU] call _kvSet;
_rec = [_rec, "state", "CREATED"] call _kvSet;
_rec = [_rec, "state_ts", _stateTsNew] call _kvSet;
_rec = [_rec, "links", _links] call _kvSet;
_rec = [_rec, "area", _area] call _kvSet;
_rec = [_rec, "classification", _classification] call _kvSet;
_rec = [_rec, "world", _world] call _kvSet;
_rec = [_rec, "telegraphing", _tele] call _kvSet;
_rec = [_rec, "outcome", _outcome] call _kvSet;
_rec = [_rec, "audit", _audit] call _kvSet;

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
    "[ARC][THREAT] ARC_fnc_threatScheduleEvent: scheduled threat_id=%1 district=%2 posture=%3 family=%4 type=%5 subtype=%6 tier=%7 target=%8 intel=%9 pos=%10",
    _threatId, _districtId, _postureU, _familyU, _typeU, _subtypeU, _tier, _targetProfile, _intelQuality, _iedPos
];

// ---------------------------------------------------------------------------
// Emit the first intel cue about the threat.
// ---------------------------------------------------------------------------
switch (_familyU) do
{
    case "IED": { [_rec, "DISCOVERED"] call ARC_fnc_iedEmitLeads; };
    case "VBIED": { [_rec, "STAGED"] call ARC_fnc_vbiedEmitLeads; };
    case "SUICIDE": { [_rec, "STAGED"] call ARC_fnc_threatLeadEmitFromOutcome; };
    default
    {
        private _isAmbush = _intentU isEqualTo "AMBUSH";
        private _leadType = if (_isAmbush) then { "RAID" } else { "QRF" };
        private _tag = if (_isAmbush) then { "AMBUSH_NETWORK" } else { "DISTRICT_ATTACK" };
        private _disp = if (_isAmbush) then
        {
            format ["Ambush Network Activity — %1", _districtId]
        }
        else
        {
            format ["District Attack Network — %1", _districtId]
        };
        private _leadId = [_leadType, _disp, _iedPos, _intelQuality, _nonIedLeadTtlS, "", _typeU, "", _tag] call ARC_fnc_leadCreate;
        if (!(_leadId isEqualTo "")) then
        {
            diag_log format ["[ARC][INFO] ARC_fnc_threatScheduleEvent: NON_IED lead=%1 threat=%2 intent=%3", _leadId, _threatId, _intentU];
        };
    };
};

true
