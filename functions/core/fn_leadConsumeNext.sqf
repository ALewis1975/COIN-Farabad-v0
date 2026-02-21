/*
    Consume (remove) one lead from the pool, returning the picked lead entry.

    Selection:
      - Command node leads preempt everything
      - TOC-requested leads (e.g., S2 requests) preempt normal weighted selection
      - Otherwise weighted random by lead strength.

    Returns:
        ARRAY - lead entry, or [] if none.

    Lead entry format:
        [id, incidentType, displayName, pos, strength, createdAt, expiresAt, sourceTaskId, sourceIncidentType, threadId, tag]
*/

if (!isServer) exitWith {[]};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

// Prune expired leads first.
[] call ARC_fnc_leadPrune;

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

if (_leads isEqualTo []) exitWith {[]};

// Command node leads are "time sensitive" and should preempt normal weighted selection.
// If present, consume the strongest command node lead first.
private _cmdIdx = -1;
private _cmdBest = -1;
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 2) then { continue; };
    private _tU = toUpper (_x select 1);
    if (_tU find "CMDNODE" != 0) then { continue; };

    private _s = 1;
    if ((count _x) > 4) then { _s = _x select 4; };
    if (_s > _cmdBest) then
    {
        _cmdBest = _s;
        _cmdIdx = _forEachIndex;
    };
} forEach _leads;

// TOC-priority leads: if S2/S3 deliberately requested collection, consume those
// before RNG. This makes "approved queue" requests reliably turn into the next
// actionable lead/task.
private _priIdx = -1;
private _priBestCreated = 1e12;
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 11) then { continue; };

    private _tag = _x select 10;
    if (!(_tag isEqualType "")) then { continue; };

    private _tU = toUpper ([_tag] call _trimFn);
    if (_tU isEqualTo "") then { continue; };

    private _isPri = false;
    if (_tU find "S2_" == 0) then { _isPri = true; };
    if (_tU find "TOC_" == 0) then { _isPri = true; };
    if (_tU find "QUEUE" == 0) then { _isPri = true; };
    if (_tU isEqualTo "S2") then { _isPri = true; };

    if (!_isPri) then { continue; };

    private _c = _x select 5; // createdAt
    if (!(_c isEqualType 0)) then { _c = serverTime; };

    // FIFO-ish: older TOC requests should be consumed first.
    if (_c < _priBestCreated) then
    {
        _priBestCreated = _c;
        _priIdx = _forEachIndex;
    };
} forEach _leads;

// Build weights
private _weights = [];
private _sum = 0;

{
    _x params ["_id", "_type", "_disp", "_pos", ["_strength", 0.5]];
    private _w = (_strength max 0.05) min 1; // floor to avoid "dead" leads
    _weights pushBack _w;
    _sum = _sum + _w;
} forEach _leads;

// Pick
private _pickIdx = 0;

if (_cmdIdx >= 0) then
{
    _pickIdx = _cmdIdx;
}
else
{
    if (_priIdx >= 0) then
    {
        _pickIdx = _priIdx;
    }
    else
    {
        if (_sum > 0) then
        {
            private _r = random _sum;
            private _acc = 0;

            {
                _acc = _acc + (_weights select _forEachIndex);
                if (_r <= _acc) exitWith { _pickIdx = _forEachIndex; };
            } forEach _leads;
        }
        else
        {
            _pickIdx = floor (random (count _leads));
        };
    };
};

// Consume selected lead
private _lead = _leads deleteAt _pickIdx;


// If this lead had an approximate circle marker, remove it once consumed into a task.
if (_lead isEqualType [] && { (count _lead) >= 1 }) then
{
    private _lid = _lead select 0;
    private _mk = format ["ARC_leadCircle_%1", _lid];
    if (_mk in allMapMarkers) then { deleteMarker _mk; };
    missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _lid], nil];
};

// Persist updated pool
["leadPool", _leads] call ARC_fnc_stateSet;

// Normalise consumed lead for zone dynamics (safety net).
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
    private _lid = _lead select 0;
    private _lh = ["leadHistory", []] call ARC_fnc_stateGet;
    if (!(_lh isEqualType [])) then { _lh = []; };
    _lh pushBack [_lid, "CONSUMED", serverTime];
    ["leadHistory", _lh] call ARC_fnc_stateSet;
};

// Broadcast updated view for clients
[] call ARC_fnc_leadBroadcast;

_lead
