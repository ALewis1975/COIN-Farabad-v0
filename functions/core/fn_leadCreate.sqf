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
        9: ARRAY  - (optional) civic mission metadata (pairs array; passed
                    through to the resulting incident so catalog-seeded missions
                    keep their structured metadata across the queue/lead path)
       10: STRING - (optional) origin: "FIELD" (default) for field-generated
                    leads (IED/CIVSUB/threat/HUMINT/etc.) or "S2" for leads
                    created by S2/Intelligence/ISR assets via the TOC. Stored as
                    an "origin" pair inside missionMeta so the positional 12-field
                    lead-record shape is preserved.

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
    ["_tag", ""],
    ["_missionMeta", []],
    ["_origin", "FIELD"]
];

if (_leadType isEqualTo "" || _displayName isEqualTo "") exitWith {""};
if !(_pos isEqualType []) exitWith {""};
if ((count _pos) < 2) exitWith {""};
if (!(_missionMeta isEqualType [])) then { _missionMeta = []; };

// First-class lead origin (field-generated vs S2/Intelligence/ISR). Default FIELD.
// A caller may instead embed an ["origin", ...] pair directly in _missionMeta; if
// present that value wins. Otherwise the _origin param value is injected so every
// lead record carries an origin discriminator.
if (!(_origin isEqualType "")) then { _origin = "FIELD"; };
_origin = toUpper _origin;
if !(_origin in ["FIELD", "S2"]) then { _origin = "FIELD"; };

private _hasOrigin = false;
for "_i" from 0 to ((count _missionMeta) - 1) do
{
    private _p = _missionMeta select _i;
    if (_p isEqualType [] && { (count _p) >= 2 } && { (_p select 0) isEqualTo "origin" }) exitWith
    {
        _hasOrigin = true;
        private _v = _p select 1;
        if (_v isEqualType "") then { _origin = toUpper _v; };
        if !(_origin in ["FIELD", "S2"]) then { _origin = "FIELD"; };
        _missionMeta set [_i, ["origin", _origin]];
    };
};
if (!_hasOrigin) then { _missionMeta pushBack ["origin", _origin]; };

_strength = (_strength max 0) min 1;

private _trimFn = compile "params ['_s']; trim _s";

private _counter = ["leadCounter", 0] call ARC_fnc_stateGet;
_counter = _counter + 1;
["leadCounter", _counter] call ARC_fnc_stateSet;

private _id = format ["ARC_lead_%1", _counter];

private _now = serverTime;
private _expiresAt = if (_expiresIn > 0) then { _now + _expiresIn } else { -1 };

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

_leads pushBack [_id, _leadType, _displayName, _pos, _strength, _now, _expiresAt, _sourceTaskId, _sourceIncidentType, _threadId, _tag, _missionMeta];

// Cap pool size to keep it sane (oldest drops off first).
// DEBT-01: cap is configurable via ARC_leadPoolCap (clamped to a safe range)
// and overflow drops are logged so operators can tell when actionable intel
// is being silently discarded by capacity pressure.
private _cap = missionNamespace getVariable ["ARC_leadPoolCap", 12];
if (!(_cap isEqualType 0) || { _cap < 4 }) then { _cap = 12; };
_cap = (_cap max 4) min 40;

while { (count _leads) > _cap } do
{
    private _dropped = _leads deleteAt 0;
    if (_dropped isEqualType [] && { (count _dropped) >= 1 }) then
    {
        private _did = _dropped select 0;
        private _mk = format ["ARC_leadCircle_%1", _did];
        if (_mk in allMapMarkers) then { deleteMarker _mk; };
        missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _did], nil];

        // Stage 5: record the eviction as a DROPPED end-state in leadHistory so the
        // S2 can audit actionable intel that aged out under capacity pressure, not
        // just an RPT/OPS line that scrolls away.
        private _lhDrop = ["leadHistory", []] call ARC_fnc_stateGet;
        if (!(_lhDrop isEqualType [])) then { _lhDrop = []; };
        _lhDrop pushBack [_did, "DROPPED", serverTime];
        ["leadHistory", _lhDrop] call ARC_fnc_stateSet;

        if (!isNil "ARC_fnc_intelLog") then
        {
            private _dType = if ((count _dropped) >= 2) then { _dropped select 1 } else { "" };
            private _dName = if ((count _dropped) >= 3) then { _dropped select 2 } else { "" };
            private _dPos  = if ((count _dropped) >= 4) then { _dropped select 3 } else { [0,0,0] };
            if (!(_dType isEqualType "")) then { _dType = ""; };
            if (!(_dName isEqualType "")) then { _dName = ""; };
            if (!(_dPos isEqualType [])) then { _dPos = [0,0,0]; };

            ["OPS",
                format ["LEAD DROPPED (pool cap %1): %2 (%3) discarded to make room for new lead.",
                    _cap, _dName, toUpper _dType],
                _dPos,
                [
                    ["event","LEAD_DROPPED_CAP"],
                    ["leadId", _did],
                    ["leadType", toUpper _dType],
                    ["cap", _cap]
                ]
            ] call ARC_fnc_intelLog;
        };
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
            ["threadId",_threadId],
            ["origin",_origin]
        ]
    ] call ARC_fnc_intelLog;
};

// Stage 4 (opt-in): auto-route high-confidence FIELD leads straight into the TOC
// Queue (backlog) at creation so "generate next incident" naturally picks them up,
// closing the "added to the lead panel but never routed" gap. Disabled by default
// to preserve the deliberate S2/TOC review cycle. S2/ISR-origin leads are never
// auto-routed — they always go through explicit TOC approval.
private _autoEnq = missionNamespace getVariable ["ARC_leadAutoEnqueueField", false];
if (!(_autoEnq isEqualType true) && !(_autoEnq isEqualType false)) then { _autoEnq = false; };
if (_autoEnq && { _origin isEqualTo "FIELD" } && { !isNil "ARC_fnc_tocBacklogEnqueue" }) then
{
    private _minStr = missionNamespace getVariable ["ARC_leadAutoEnqueueMinStrength", 0.7];
    if (!(_minStr isEqualType 0)) then { _minStr = 0.7; };
    _minStr = (_minStr max 0) min 1;

    if (_strength >= _minStr) then
    {
        [_id, 3, "", "AUTO", "Auto-routed high-confidence field lead."] call ARC_fnc_tocBacklogEnqueue;
    };
};

_id
