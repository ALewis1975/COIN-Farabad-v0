/*
    ARC_fnc_recruitClientAddActions

    Client: attach AI recruitment addActions to one container object.

    Params:
      0: OBJECT container

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_container", objNull, [objNull]]
];

if (isNull _container) exitWith {false};
if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};

private _whitelist = missionNamespace getVariable ["ARC_recruitUnitWhitelist", []];
if (!(_whitelist isEqualType [])) then { _whitelist = []; };
if ((count _whitelist) isEqualTo 0) exitWith {false};

private _signature = str _whitelist;
if ((_container getVariable ["ARC_recruitActionsSignature", ""]) isEqualTo _signature) exitWith {true};

private _old = _container getVariable ["ARC_recruitActionIds", []];
if (_old isEqualType []) then
{
    {
        if (_x isEqualType 0 && { _x >= 0 }) then
        {
            _container removeAction _x;
        };
    } forEach _old;
};

private _range = missionNamespace getVariable ["ARC_recruitActionRangeM", 6];
if (!(_range isEqualType 0)) then { _range = 6; };
_range = (_range max 2) min 15;

private _ids = [];
{
    private _class = "";
    private _label = "";

    if (_x isEqualType "") then
    {
        _class = _x;
    }
    else
    {
        if (_x isEqualType [] && { (count _x) >= 1 }) then
        {
            private _c0 = _x select 0;
            if (_c0 isEqualType "") then { _class = _c0; };
            if ((count _x) >= 2) then
            {
                private _c1 = _x select 1;
                if (_c1 isEqualType "") then { _label = _c1; };
            };
        };
    };

    if (_class isEqualTo "") then { continue; };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) then { continue; };
    if (!(_class isKindOf "Man")) then { continue; };

    if (_label isEqualTo "") then
    {
        _label = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
        if (_label isEqualTo "") then { _label = _class; };
    };

    private _text = format ["[Recruit] %1", _label];
    private _cond = format [
        "alive _target && {_this distance _target <= %1} && {[_this] call ARC_fnc_rolesCanRecruitAI}",
        _range
    ];

    private _id = _container addAction [
        _text,
        {
            params ["_target", "_caller", ["_actionId", -1, [0]], "_args"];
            if (_actionId < 0) exitWith {false};
            _args params [
                ["_class", "", [""]]
            ];
            if (_class isEqualTo "") exitWith {false};
            [_caller, _target, _class] remoteExec ["ARC_fnc_recruitSpawnRequest", 2];
            true
        },
        [_class],
        1.1,
        true,
        true,
        "",
        _cond,
        _range
    ];
    _ids pushBack _id;
} forEach _whitelist;

_container setVariable ["ARC_recruitActionIds", _ids, false];
_container setVariable ["ARC_recruitActionsSignature", _signature, false];

(count _ids) > 0
