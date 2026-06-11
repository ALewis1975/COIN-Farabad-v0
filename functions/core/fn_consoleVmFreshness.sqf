/*
    ARC_fnc_consoleVmFreshness

    Client-side: read the freshness metadata of a named Console VM section.

    Params:
      0: STRING - section name (e.g. "ops", "intelFeed", "handoff")

    Returns:
      ARRAY - [updatedAt, staleAfterS, isStale]
        updatedAt  : NUMBER serverTime stamp from the section freshness (-1 when unavailable)
        staleAfterS: NUMBER TTL from the section freshness (-1 when unavailable)
        isStale    : BOOL true when updatedAt/TTL are present and age exceeds TTL

    Usage:
      (["ops"] call ARC_fnc_consoleVmFreshness) params ["_updatedAt", "_ttl", "_isStale"];
*/

if (!hasInterface) exitWith { [-1, -1, false] };

params [
    ["_sectionName", "", [""]]
];

if (_sectionName isEqualTo "") exitWith { [-1, -1, false] };

private _payload = missionNamespace getVariable ["ARC_consoleVM_payload", []];
if (!(_payload isEqualType []) || { _payload isEqualTo [] }) exitWith { [-1, -1, false] };

private _sections = [];
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "sections" }) exitWith {
        _sections = _x select 1;
    };
} forEach _payload;

if (!(_sections isEqualType []) || { _sections isEqualTo [] }) exitWith { [-1, -1, false] };

private _freshness = [];
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _sectionName }) exitWith {
        private _sec = _x select 1;
        if (_sec isEqualType []) then
        {
            {
                if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "freshness" }) exitWith {
                    _freshness = _x select 1;
                };
            } forEach _sec;
        };
    };
} forEach _sections;

if (!(_freshness isEqualType []) || { _freshness isEqualTo [] }) exitWith { [-1, -1, false] };

private _updatedAt = -1;
private _ttl = -1;
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then
    {
        if ((_x select 0) isEqualTo "updatedAt" && { (_x select 1) isEqualType 0 }) then { _updatedAt = _x select 1; };
        if ((_x select 0) isEqualTo "staleAfterS" && { (_x select 1) isEqualType 0 }) then { _ttl = _x select 1; };
    };
} forEach _freshness;

private _isStale = false;
if (_updatedAt > 0 && { _ttl > 0 }) then
{
    _isStale = (serverTime - _updatedAt) > _ttl;
};

[_updatedAt, _ttl, _isStale]
