/*
    Create a new lead and push it into the lead pool.

    Params:
        0: STRING - lead incident type (e.g. "RAID", "IED", "RECON", "CIVIL", "QRF", "DEFEND", ...)
        1: STRING - display name
        2: ARRAY  - position [x,y,z]
        3: NUMBER - strength/weight (0..1, used for lead selection)
        4: NUMBER - expires in seconds (0 = never)
        5: STRING - (optional) source taskId
        6: STRING - (optional) source incident type
        7: STRING - (optional) threadId ("ARC_thr_#")
        8: STRING - (optional) tag (e.g. "CMDNODE")

    Returns:
        STRING - leadId ("" if failed)
*/

if (!isServer) exitWith {""};

params [
    "_leadType",
    "_displayName",
    "_pos",
    ["_strength", 0.5],
    ["_expiresIn", 3600],
    ["_sourceTaskId", ""],
    ["_sourceIncidentType", ""],
    ["_threadId", ""],
    ["_tag", ""]
];

if (_leadType isEqualTo "" || _displayName isEqualTo "") exitWith {""};
if !(_pos isEqualType []) exitWith {""};
if ((count _pos) < 2) exitWith {""};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

_strength = (_strength max 0) min 1;

private _counter = ["leadCounter", 0] call ARC_fnc_stateGet;
_counter = _counter + 1;
["leadCounter", _counter] call ARC_fnc_stateSet;

private _id = format ["ARC_lead_%1", _counter];

private _now = serverTime;
private _expiresAt = if (_expiresIn > 0) then { _now + _expiresIn } else { -1 };

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

_leads pushBack [_id, _leadType, _displayName, _pos, _strength, _now, _expiresAt, _sourceTaskId, _sourceIncidentType, _threadId, _tag];

// Cap pool size to keep it sane (oldest drops off first).
private _cap = 12;

if ((count _leads) > _cap) then
{
    private _dropped = _leads deleteAt 0;
    if (_dropped isEqualType [] && { (count _dropped) >= 1 }) then
    {
        private _did = _dropped select 0;
        private _mk = format ["ARC_leadCircle_%1", _did];
        if (_mk in allMapMarkers) then { deleteMarker _mk; };
        missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _did], nil];
    };
};

["leadPool", _leads] call ARC_fnc_stateSet;


// Breadcrumbs for debug/TOC tools
["lastLeadCreated", [_id, _leadType, _displayName, _pos, _strength, _now, _expiresAt, _sourceTaskId, _sourceIncidentType, _threadId, _tag]] call ARC_fnc_stateSet;

// Suspicious lead circles (approximate only)
private _circlesOn = missionNamespace getVariable ["ARC_suspiciousLeadCirclesEnabled", true];
if (!(_circlesOn isEqualType true) && !(_circlesOn isEqualType false)) then { _circlesOn = true; };

private _tU = toUpper ([_tag] call _trimFn);
if (_circlesOn && { _tU find "SUS_" == 0 }) then
{
    private _mkName = format ["ARC_leadCircle_%1", _id];

    // TTL: use lead expiry if present, else fall back to configured TTL.
    private _ttlFallback = missionNamespace getVariable ["ARC_suspiciousLeadCircleTtlSec", 75*60];
    if (!(_ttlFallback isEqualType 0) || { _ttlFallback <= 0 }) then { _ttlFallback = 75*60; };

    private _rad = missionNamespace getVariable ["ARC_suspiciousLeadCircleRadiusM_activity", 450];
    if (_tU isEqualTo "SUS_VEHICLE") then { _rad = missionNamespace getVariable ["ARC_suspiciousLeadCircleRadiusM_vehicle", 350]; };
    if (_tU isEqualTo "SUS_PERSON") then { _rad = missionNamespace getVariable ["ARC_suspiciousLeadCircleRadiusM_person", 250]; };

    if (!(_rad isEqualType 0) || { _rad <= 0 }) then { _rad = 350; };
    _rad = (_rad max 75) min 1200;

    private _jit = missionNamespace getVariable ["ARC_suspiciousLeadCircleCenterJitterM", 120];
    if (!(_jit isEqualType 0) || { _jit < 0 }) then { _jit = 120; };
    _jit = (_jit max 0) min 600;

    private _p = +_pos; _p resize 3;
    if (_jit > 0) then
    {
        _p = _p getPos [random _jit, random 360];
        _p resize 3;
    };

    private _p2 = +_p; _p2 resize 2;

    if !(_mkName in allMapMarkers) then
    {
        createMarker [_mkName, _p2];
    }
    else
    {
        _mkName setMarkerPos _p2;
    };

    _mkName setMarkerShape "ELLIPSE";
    _mkName setMarkerBrush "SolidBorder";
    _mkName setMarkerColor "ColorOrange";
    _mkName setMarkerAlpha 0.25;
    _mkName setMarkerSize [_rad, _rad];
    _mkName setMarkerText "Possible contact";

    // Store marker expiry so prune/consume can clean it up deterministically.
    private _exp = _expiresAt;
    if (!(_exp isEqualType 0)) then { _exp = -1; };
    if (_exp <= 0) then { _exp = _now + _ttlFallback; };
    missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _id], _exp];
};
// Keep clients in the loop (tiny payload, big QoL)
[] call ARC_fnc_leadBroadcast;

// OPS breadcrumbs (also written to RPT if ARC_rptOpsLogEnabled is true)
if (!isNil "ARC_fnc_intelLog") then
{
    ["OPS",
        format ["Lead created: %1 (%2).", _displayName, toUpper _leadType],
        _pos,
        [
            ["event","LEAD_CREATED"],
            ["leadId",_id],
            ["leadType",toUpper _leadType],
            ["tag",_tag],
            ["sourceTaskId",_sourceTaskId],
            ["sourceIncidentType",toUpper _sourceIncidentType],
            ["threadId",_threadId]
        ]
    ] call ARC_fnc_intelLog;
};

_id
