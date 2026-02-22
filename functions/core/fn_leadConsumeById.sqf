/*
    ARC_fnc_leadConsumeById

    Server: consume (remove) a specific lead from the pool, returning the picked lead entry.

    Params:
      0: STRING leadId

    Returns:
      ARRAY - lead entry (same structure as leadConsumeNext), or [] if not found.

    Lead entry format:
      [id, incidentType, displayName, pos, strength, createdAt, expiresAt, sourceTaskId, sourceIncidentType, threadId, tag]
*/

if (!isServer) exitWith {[]};

params [ ["_leadId", "", [""]] ];
_leadId = trim _leadId;
if (_leadId isEqualTo "") exitWith {[]};

// Prune expired leads first.
[] call ARC_fnc_leadPrune;

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

if (_leads isEqualTo []) exitWith {[]};

private _idx = _leads findIf {
    _x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _leadId }
};

if (_idx < 0) exitWith {[]};

// Consume selected lead
private _lead = _leads deleteAt _idx;

// If this lead had an approximate circle marker, remove it once consumed into a task.
if (_lead isEqualType [] && { (count _lead) >= 1 }) then
{
    private _lid = _lead # 0;
    private _mk = format ["ARC_leadCircle_%1", _lid];
    if (_mk in allMapMarkers) then { deleteMarker _mk; };
    missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _lid], nil];
};

// Persist updated pool
["leadPool", _leads] call ARC_fnc_stateSet;

// Normalise consumed lead for zone dynamics (safety net). Mirrors ARC_fnc_leadConsumeNext.
if (_lead isEqualType [] && { (count _lead) >= 4 }) then
{
    _lead params [
        "_id",
        "_type",
        "_disp",
        "_pos",
        ["_strength", 0.5],
        ["_createdAt", -1],
        ["_expiresAt", -1],
        ["_sourceTaskId", ""],
        ["_sourceType", ""],
        ["_threadId", ""],
        ["_tag", ""]
    ];

    private _typeU = toUpper _type;
    private _sourceU = toUpper _sourceType;

    private _zone = "";
    if (_pos isEqualType [] && { (count _pos) >= 2 }) then
    {
        _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
    };

    private _secureZones = ["Airbase", "GreenZone"];

    // IED activity inside secure zones is weird. Convert to an intercept/surveillance lead and move it outside.
    if (_typeU isEqualTo "IED" && { _zone in _secureZones }) then
    {
        _type = "RECON";
        _disp = "Lead: Suspect Vehicle Spotted Outside Secure Zone";
        _pos = [_pos, 1600, _secureZones] call ARC_fnc_worldPickEnterablePosNear;
    };

    // Hideout/safehouse leads produced by IED/RECON successes should point OUTSIDE secure zones.
    if (_typeU isEqualTo "RAID" && { _sourceU in ["IED", "RECON"] } && { _zone in _secureZones }) then
    {
        _pos = [_pos, 1600, _secureZones] call ARC_fnc_worldPickEnterablePosNear;
    };

    // Rebuild lead entry with any edits
    _lead = [_id, _type, _disp, _pos, _strength, _createdAt, _expiresAt, _sourceTaskId, _sourceType, _threadId, _tag];
};

// Breadcrumbs for TOC/debug
["lastLeadConsumed", _lead] call ARC_fnc_stateSet;

// Track lead end-state (consumed into an actionable task)
if (_lead isEqualType [] && { (count _lead) >= 1 }) then
{
    private _lid = _lead # 0;
    private _lh = ["leadHistory", []] call ARC_fnc_stateGet;
    if (!(_lh isEqualType [])) then { _lh = []; };
    _lh pushBack [_lid, "CONSUMED", serverTime];
    ["leadHistory", _lh] call ARC_fnc_stateSet;
};

// Broadcast updated view for clients
[] call ARC_fnc_leadBroadcast;

_lead
