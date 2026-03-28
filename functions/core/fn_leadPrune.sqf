/*
    Prune expired leads from the lead pool.

    Returns:
        NUMBER - count of removed leads
*/

if (!isServer) exitWith {0};

private _trimFn = compile "params ['_s']; trim _s";

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

private _now = serverTime;
private _before = count _leads;

// Track which leads expire (for end-state reporting)
private _expiredIds = [];
{
    if (_x isEqualType [] && { (count _x) >= 7 }) then
    {
        private _expiresAt = _x select 6;
        if (_expiresAt isEqualType 0 && { _expiresAt > 0 } && { _expiresAt <= _now }) then
        {
            _expiredIds pushBack (_x select 0);
        };
    };
} forEach _leads;

// Keep anything with no expiry, or expiry in the future.
_leads = _leads select
{
    _x params ["_id", "_type", "_disp", "_pos", ["_strength", 0.5], ["_createdAt", -1], ["_expiresAt", -1]];
    (_expiresAt <= 0) || { _expiresAt > _now }
};



// Safety net: if a suspicious lead circle has a TTL, remove its marker even if the lead itself does not expire.
{
    if (!(_x isEqualType []) || { (count _x) < 11 }) then { continue; };
    private _id = _x select 0;
    private _tag = _x select 10;
    if (!(_tag isEqualType "")) then { continue; };

    private _tU = toUpper ([_tag] call _trimFn);
    if (_tU find "SUS_" != 0) then { continue; };

    private _exp = missionNamespace getVariable [format ["ARC_leadCircleExpiresAt_%1", _id], -1];
    if (!(_exp isEqualType 0) || { _exp <= 0 }) then { continue; };

    if (_exp <= _now) then
    {
        private _mk = format ["ARC_leadCircle_%1", _id];
        if (_mk in allMapMarkers) then { deleteMarker _mk; };
        missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _id], nil];
    };
} forEach _leads;

private _after = count _leads;
private _removed = _before - _after;

if (_removed > 0) then
{
    ["leadPool", _leads] call ARC_fnc_stateSet;


// Remove any suspicious lead circle markers for expired leads.
{
    private _mk = format ["ARC_leadCircle_%1", _x];
    if (_mk in allMapMarkers) then { deleteMarker _mk; };
    missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _x], nil];
} forEach _expiredIds;

    // Lead end-state: expired (never actioned)
    if (!(_expiredIds isEqualTo [])) then
    {
        private _lh = ["leadHistory", []] call ARC_fnc_stateGet;
        if (!(_lh isEqualType [])) then { _lh = []; };
        {
            _lh pushBack [_x, "EXPIRED", _now];
        } forEach _expiredIds;
        ["leadHistory", _lh] call ARC_fnc_stateSet;
    };

    // Keep clients up to date for TOC tools
    [] call ARC_fnc_leadBroadcast;
};

_removed
