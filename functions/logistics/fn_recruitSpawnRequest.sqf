/*
    ARC_fnc_recruitSpawnRequest

    Server: validate a player recruitment request and spawn one whitelisted,
    same-faction AI unit into the player's group.

    Params:
      0: OBJECT caller
      1: OBJECT container
      2: STRING unit classname

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull, [objNull]],
    ["_container", objNull, [objNull]],
    ["_unitClass", "", [""]]
];

private _owner = -1;
if (!isNil "remoteExecutedOwner") then { _owner = remoteExecutedOwner; };

if (!([_caller, "ARC_fnc_recruitSpawnRequest", "Recruit request rejected: sender verification failed.", "RECRUIT_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};
if (isNull _caller || { isNull _container }) exitWith {false};
if !(isPlayer _caller) exitWith {false};

if (!([_caller] call ARC_fnc_rolesCanRecruitAI)) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: role denied caller=%1 uid=%2", name _caller, getPlayerUID _caller];
    if (_owner > 0) then { ["Recruitment", "Recruitment is restricted to Battalion/Company command."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _classes = missionNamespace getVariable ["ARC_recruitContainerClasses", ["B_Slingload_01_Cargo_F"]];
if (!(_classes isEqualType [])) then { _classes = ["B_Slingload_01_Cargo_F"]; };
if (!((typeOf _container) in _classes)) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: invalid container type=%1 caller=%2", typeOf _container, name _caller];
    false
};

if (!(_container getVariable ["ARC_isRecruitContainer", false])) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: unregistered recruitment container netId=%1 type=%2 caller=%3", netId _container, typeOf _container, name _caller];
    false
};

private _range = missionNamespace getVariable ["ARC_recruitActionRangeM", 6];
if (!(_range isEqualType 0)) then { _range = 6; };
_range = (_range max 2) min 15;
if ((_caller distance2D _container) > (_range + 1)) exitWith
{
    if (_owner > 0) then { ["Recruitment", "Move closer to the recruitment container."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _whitelist = missionNamespace getVariable ["ARC_recruitUnitWhitelist", []];
if (!(_whitelist isEqualType [])) then { _whitelist = []; };

private _allowed = false;
private _label = _unitClass;
{
    private _class = "";
    private _display = "";

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
                if (_c1 isEqualType "") then { _display = _c1; };
            };
        };
    };

    if (_class isEqualTo _unitClass) exitWith
    {
        _allowed = true;
        if (!(_display isEqualTo "")) then { _label = _display; };
    };
} forEach _whitelist;

if (!_allowed) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: class not whitelisted class=%1 caller=%2", _unitClass, name _caller];
    if (_owner > 0) then { ["Recruitment", "Requested unit type is not whitelisted."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _cfg = configFile >> "CfgVehicles" >> _unitClass;
if (!isClass _cfg || { !(_unitClass isKindOf "Man") }) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_recruitSpawnRequest: invalid unit class=%1", _unitClass];
    false
};

private _callerGroup = group _caller;
if (isNull _callerGroup) exitWith {false};

private _side = side _callerGroup;
private _sideNum = 1;
if (_side isEqualTo east) then { _sideNum = 0; };
if (_side isEqualTo west) then { _sideNum = 1; };
if (_side isEqualTo independent) then { _sideNum = 2; };
if (_side isEqualTo civilian) then { _sideNum = 3; };

if ((getNumber (_cfg >> "side")) != _sideNum) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: side mismatch class=%1 callerSide=%2", _unitClass, _side];
    if (_owner > 0) then { ["Recruitment", "Requested unit type is not on your side."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _requireSameFaction = missionNamespace getVariable ["ARC_recruitRequireSameFaction", true];
if (!(_requireSameFaction isEqualType true) && !(_requireSameFaction isEqualType false)) then { _requireSameFaction = true; };
private _factionOk = true;
private _callerFaction = faction _caller;
private _unitFaction = getText (_cfg >> "faction");
if (_requireSameFaction) then
{
    _factionOk = _unitFaction isEqualTo _callerFaction;
};
if (!_factionOk) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: faction mismatch class=%1 unitFaction=%2 callerFaction=%3", _unitClass, _unitFaction, _callerFaction];
    if (_owner > 0) then { ["Recruitment", "Requested unit type is not from your faction."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _maxGroupUnits = missionNamespace getVariable ["ARC_recruitGroupMaxUnits", 12];
if (!(_maxGroupUnits isEqualType 0)) then { _maxGroupUnits = 12; };
_maxGroupUnits = (_maxGroupUnits max 2) min 24;

private _groupUnits = units _callerGroup;
if ((count _groupUnits) >= _maxGroupUnits) exitWith
{
    if (_owner > 0) then { ["Recruitment", format ["Group is already at the recruitment cap (%1).", _maxGroupUnits]] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _spawnPos = (getPosATL _container) getPos [4 + random 2, random 360];
_spawnPos resize 3;
_spawnPos set [2, 0];

private _spawnGroup = createGroup [_side, true];
private _unit = _spawnGroup createUnit [_unitClass, _spawnPos, [], 0, "NONE"];
if (isNull _unit) exitWith
{
    deleteGroup _spawnGroup;
    diag_log format ["[ARC][WARN] ARC_fnc_recruitSpawnRequest: createUnit failed class=%1", _unitClass];
    if (_owner > 0) then { ["Recruitment", "Unable to spawn that unit type."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

_unit setPosATL _spawnPos;
[_unit] joinSilent _callerGroup;
deleteGroup _spawnGroup;

_unit setVariable ["ARC_recruitedAI", true, true];
_unit setVariable ["ARC_recruitedByUid", getPlayerUID _caller, true];
_unit setVariable ["ARC_recruitedByName", name _caller, true];
_unit setVariable ["ARC_recruitContainerNetId", netId _container, true];
_unit setVariable ["ARC_recruitSpawnedAt", serverTime, true];

if (_label isEqualTo _unitClass) then
{
    private _displayName = getText (_cfg >> "displayName");
    if (!(_displayName isEqualTo "")) then { _label = _displayName; };
};

diag_log format ["[ARC][INFO] ARC_fnc_recruitSpawnRequest: spawned class=%1 caller=%2 group=%3", _unitClass, name _caller, groupId _callerGroup];
if (_owner > 0) then { ["Recruitment", format ["%1 joined your group.", _label]] remoteExec ["ARC_fnc_clientToast", _owner]; };

true
