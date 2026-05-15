/*
    ARC_fnc_rolesCanRecruitAI

    Returns TRUE if the unit may recruit AI from command recruitment containers.

    Default gate:
      - Battalion command (ARC_fnc_rolesIsTocCommand)
      - Company command exact group IDs / roleDescription suffixes

    Optional overrides:
      - ARC_recruitCompanyCommandGroupIds : ARRAY of exact group/roleDescription IDs
      - ARC_recruitCommandRoleTokens      : ARRAY of extra groupId tokens

    Params:
      0: OBJECT unit

    Returns:
      BOOL
*/

params [
    ["_unit", objNull, [objNull]]
];

if (isNull _unit) exitWith {false};

if (!isNil "ARC_fnc_rolesIsTocCommand") then
{
    if ([_unit] call ARC_fnc_rolesIsTocCommand) exitWith {true};
};

private _trimFn = compile "params ['_s']; trim _s";

private _companyIds = missionNamespace getVariable [
    "ARC_recruitCompanyCommandGroupIds",
    [
        "A-2-325 AIR | REDFALCON 1",
        "B-2-325 AIR | REDFALCON 2",
        "B-2-325 AIR | REDFALCON 3",
        "C-2-325 AIR | REDFALCON 3"
    ]
];
if (!(_companyIds isEqualType [])) then { _companyIds = []; };

private _companyIdsU = [];
{
    if (_x isEqualType "") then
    {
        private _id = toUpper ([_x] call _trimFn);
        if (!(_id isEqualTo "")) then { _companyIdsU pushBackUnique _id; };
    };
} forEach _companyIds;

private _candidates = [];
private _grp = group _unit;
if (!isNull _grp) then
{
    private _gid = groupId _grp;
    if (_gid isEqualType "") then { _candidates pushBack _gid; };
};

private _rd = roleDescription _unit;
if (_rd isEqualType "") then
{
    private _at = _rd find "@";
    if (_at >= 0) then
    {
        _candidates pushBack (_rd select [_at + 1]);
    }
    else
    {
        _candidates pushBack _rd;
    };
};

private _ok = false;
{
    private _candidate = toUpper ([_x] call _trimFn);
    if (!(_candidate isEqualTo "") && { _candidate in _companyIdsU }) exitWith
    {
        _ok = true;
    };
} forEach _candidates;

if (_ok) exitWith {true};

private _extraTokens = missionNamespace getVariable ["ARC_recruitCommandRoleTokens", []];
if (_extraTokens isEqualType [] && { (count _extraTokens) > 0 } && { !isNil "ARC_fnc_rolesHasGroupIdToken" }) exitWith
{
    [_unit, _extraTokens] call ARC_fnc_rolesHasGroupIdToken
};

false
