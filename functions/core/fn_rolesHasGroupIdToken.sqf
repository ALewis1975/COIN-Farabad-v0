/*
    ARC_fnc_rolesHasGroupIdToken

    Returns TRUE if the unit's group callsign (groupId) contains one or more tokens.

    Why:
      - TOC-layer permissions are best enforced by callsign/group assignment
        (e.g., "2-325 AIR | REDFALCON S2") rather than generic leader classnames.

    Params:
      0: OBJECT unit
      1: STRING or ARRAY of STRING tokens
      2: BOOL requireAll (optional, default false)
      3: BOOL fallbackRoleDesc (optional, default true)

    Examples:
      [player, "REDFALCON S2"] call ARC_fnc_rolesHasGroupIdToken;
      [player, ["REDFALCON", "S3"], true] call ARC_fnc_rolesHasGroupIdToken;
*/

params [
    ["_unit", objNull, [objNull]],
    ["_tokens", "", ["", []]],
    ["_requireAll", false, [true]],
    ["_fallbackRoleDesc", true, [true]]
];

if (isNull _unit) exitWith {false};

private _hay = "";
private _grp = group _unit;
if (!isNull _grp) then { _hay = groupId _grp; };

if (!(_hay isEqualType "")) then { _hay = ""; };
_hay = trim _hay;

// Fallback: lobby/editor description can include the callsign string.
// Append roleDescription even when groupId is non-empty.
// Some slots keep a default groupId while roleDescription contains the callsign.
if (_fallbackRoleDesc) then
{
    private _rd = roleDescription _unit;
    if (!(_rd isEqualType "")) then { _rd = ""; };
    _rd = trim _rd;

    if (_rd isNotEqualTo "") then
    {
        if (_hay isEqualTo "") then { _hay = _rd; } else { _hay = _hay + " " + _rd; };
    };
};

if (_hay isEqualTo "") exitWith {false};

private _hayU = toUpper _hay;

private _tokList = [];
if (_tokens isEqualType "") then
{
    private _t = trim _tokens;
    if (_t isNotEqualTo "") then { _tokList = [_t]; };
}
else
{
    {
        if (_x isEqualType "") then
        {
            private _t = trim _x;
            if (_t isNotEqualTo "") then { _tokList pushBack _t; };
        };
    } forEach _tokens;
};

if (_tokList isEqualTo []) exitWith {false};

private _hits = 0;
{
    private _tU = toUpper _x;
    if (_tU isEqualTo "") then { continue; };
    if ((_hayU find _tU) >= 0) then
    {
        _hits = _hits + 1;
    };
} forEach _tokList;

if (_requireAll) exitWith { _hits isEqualTo (count _tokList) };

_hits > 0
