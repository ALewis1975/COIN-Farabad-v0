/*
    ARC_fnc_civsubLeadEmitBridge

    Server-side bridge: materialize CIVSUB bundle lead_emit payloads into core leadPool
    via ARC_fnc_leadCreate.

    Params:
      0: HashMap bundle (CIVSUB bundle contract)

    Returns:
      STRING createdLeadId ("" when no lead emitted / rejected)
*/

if (!isServer) exitWith {""};

params [["_bundle", createHashMap, [createHashMap]]];
if !(_bundle isEqualType createHashMap) exitWith {""};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _lead = [_bundle, "lead_emit", createHashMap] call _hg;
if (_lead isEqualType []) then { _lead = [_lead] call _hmCreate; };
if !(_lead isEqualType createHashMap) exitWith {""};

if !([_lead, "emit", false] call _hg) exitWith {""};

private _civsubType = [_lead, "lead_type", ""] call _hg;
if !(_civsubType isEqualType "") then { _civsubType = ""; };
_civsubType = toUpper (trim _civsubType);
if (_civsubType isEqualTo "") exitWith {""};

private _seed = [_lead, "seed", createHashMap] call _hg;
if (_seed isEqualType []) then { _seed = [_seed] call _hmCreate; };
if !(_seed isEqualType createHashMap) then { _seed = createHashMap; };

private _source = [_bundle, "source", createHashMap] call _hg;
if (_source isEqualType []) then { _source = [_source] call _hmCreate; };
if !(_source isEqualType createHashMap) then { _source = createHashMap; };

private _districtId = [_bundle, "districtId", ([_bundle, "district_id", ""] call _hg)] call _hg;
if !(_districtId isEqualType "") then { _districtId = ""; };
_districtId = toUpper (trim _districtId);

private _confidence = [_lead, "confidence", 0.35] call _hg;
if !(_confidence isEqualType 0) then { _confidence = 0.35; };
_confidence = (_confidence max 0.10) min 0.90;

// CIVSUB lead caps (guardrails)
private _capGlobal = missionNamespace getVariable ["civsub_v1_leadBridge_capGlobalPerHour", 8];
if !(_capGlobal isEqualType 0) then { _capGlobal = 8; };
_capGlobal = (_capGlobal max 1) min 200;

private _capDistrict = missionNamespace getVariable ["civsub_v1_leadBridge_capDistrictPerHour", 2];
if !(_capDistrict isEqualType 0) then { _capDistrict = 2; };
_capDistrict = (_capDistrict max 1) min 50;

private _windowStart = serverTime - 3600;

private _hist = missionNamespace getVariable ["civsub_v1_leadBridge_history", []];
if !(_hist isEqualType []) then { _hist = []; };

// prune old history and normalize row shape: [ts, districtId, leadId, civsubType, coreType]
_hist = _hist select {
    _x isEqualType []
    && { (count _x) >= 5 }
    && { (_x select 0) isEqualType 0 }
    && { (_x select 0) >= _windowStart }
};

private _globalCount = count _hist;
if (_globalCount >= _capGlobal) exitWith {
    missionNamespace setVariable ["civsub_v1_leadBridge_history", _hist, true];
    missionNamespace setVariable ["civsub_v1_lastLeadBridgeReject", [serverTime, "CAP_GLOBAL", _globalCount, _capGlobal], true];
    ""
};

private _districtCount = count (_hist select {
    _x isEqualType []
    && { (count _x) >= 2 }
    && { (_x select 1) isEqualType "" }
    && { (toUpper (_x select 1)) isEqualTo _districtId }
});

if (!(_districtId isEqualTo "") && { _districtCount >= _capDistrict }) exitWith {
    missionNamespace setVariable ["civsub_v1_leadBridge_history", _hist, true];
    missionNamespace setVariable ["civsub_v1_lastLeadBridgeReject", [serverTime, "CAP_DISTRICT", _districtId, _districtCount, _capDistrict], true];
    ""
};

// Type mapping CIVSUB -> core incident lead types
private _coreType = switch (_civsubType) do
{
    case "LEAD_DETAIN_SUSPECT": { "RECON" };
    case "HUMINT": { "RECON" };
    case "TIP": { "RECON" };
    case "SUSPICIOUS_ACTIVITY": { "CHECKPOINT" };
    default { "RECON" };
};

private _pos = [];
private _seedPos = [_seed, "home_pos", []] call _hg;
if (_seedPos isEqualType [] && { (count _seedPos) >= 2 }) then
{
    _pos = +_seedPos;
    _pos resize 3;
};

if (_pos isEqualTo []) then
{
    private _cent = [_bundle, "district_centroid", []] call _hg;
    if !(_cent isEqualType []) then { _cent = [_bundle, "centroid", []] call _hg; };
    if (_cent isEqualType [] && { (count _cent) >= 2 }) then
    {
        _pos = +_cent;
        _pos resize 3;
    };
};

if (_pos isEqualTo []) exitWith {
    missionNamespace setVariable ["civsub_v1_leadBridge_history", _hist, true];
    missionNamespace setVariable ["civsub_v1_lastLeadBridgeReject", [serverTime, "NO_POS", _districtId, _civsubType], true];
    ""
};

private _disp = switch (_civsubType) do
{
    case "LEAD_DETAIN_SUSPECT": { "Lead: Detain suspect follow-up" };
    case "HUMINT": { "Lead: HUMINT follow-up" };
    case "TIP": { "Lead: Civilian tip follow-up" };
    case "SUSPICIOUS_ACTIVITY": { "Lead: Suspicious activity follow-up" };
    default { "Lead: CIVSUB follow-up" };
};

private _ttl = missionNamespace getVariable ["civsub_v1_leadBridge_ttlSec", 60 * 60];
if !(_ttl isEqualType 0) then { _ttl = 60 * 60; };
_ttl = (_ttl max (10 * 60)) min (6 * 60 * 60);

private _srcEvent = [_source, "event", ""] call _hg;
if !(_srcEvent isEqualType "") then { _srcEvent = ""; };
_srcEvent = toUpper (trim _srcEvent);

private _tag = if (_srcEvent isEqualTo "") then { "CIVSUB" } else { format ["CIVSUB_%1", _srcEvent] };

private _leadId = [_coreType, _disp, _pos, _confidence, _ttl, "", "CIVSUB", "", _tag] call ARC_fnc_leadCreate;
if !(_leadId isEqualType "") then { _leadId = ""; };
if (_leadId isEqualTo "") exitWith {
    missionNamespace setVariable ["civsub_v1_leadBridge_history", _hist, true];
    missionNamespace setVariable ["civsub_v1_lastLeadBridgeReject", [serverTime, "CREATE_FAIL", _districtId, _coreType, _civsubType], true];
    ""
};

// write-through for traceability on bundle + lead_emit
_lead set ["lead_id", _leadId];
_bundle set ["lead_emit", _lead];

_hist pushBack [serverTime, _districtId, _leadId, _civsubType, _coreType];
missionNamespace setVariable ["civsub_v1_leadBridge_history", _hist, true];
missionNamespace setVariable ["civsub_v1_lastLeadBridgeCreated", [serverTime, _districtId, _leadId, _civsubType, _coreType], true];

_leadId
