/*
    ARC_fnc_recruitSpawnRequest

    Server: validate a player recruitment request and spawn same-faction
    infantry AI into the player's group.

    Params:
      0: OBJECT caller
      1: OBJECT recruitment object
      2: STRING unit classname
      3: NUMBER count

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull, [objNull]],
    ["_container", objNull, [objNull]],
    ["_unitClass", "", [""]],
    ["_count", 1, [0]]
];

private _owner = -1;
if (!isNil "remoteExecutedOwner") then { _owner = remoteExecutedOwner; };

if (!([_caller, "ARC_fnc_recruitSpawnRequest", "Recruit request rejected: sender verification failed.", "RECRUIT_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};
if (isNull _caller || { isNull _container }) exitWith {false};
if !(isPlayer _caller) exitWith {false};

if (!(_container getVariable ["ARC_isRecruitContainer", false])) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: unregistered recruitment object netId=%1 type=%2 caller=%3", netId _container, typeOf _container, name _caller];
    false
};

_count = floor _count;
if (_count < 1) then { _count = 1; };
if (_count > 12) then { _count = 12; };

private _cfg = configFile >> "CfgVehicles" >> _unitClass;
if (!isClass _cfg || { !(_unitClass isKindOf "CAManBase") }) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_recruitSpawnRequest: invalid unit class=%1", _unitClass];
    false
};
if ((getNumber (_cfg >> "scope")) < 2) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: non-public unit class=%1 caller=%2", _unitClass, name _caller];
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

private _callerFaction = faction _caller;
private _unitFaction = getText (_cfg >> "faction");
if (!(_unitFaction isEqualTo _callerFaction)) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_recruitSpawnRequest: faction mismatch class=%1 unitFaction=%2 callerFaction=%3", _unitClass, _unitFaction, _callerFaction];
    if (_owner > 0) then { ["Recruitment", "Requested unit type is not from your faction."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _maxGroupUnits = missionNamespace getVariable ["ARC_recruitGroupMaxUnits", 12];
if (!(_maxGroupUnits isEqualType 0)) then { _maxGroupUnits = 12; };
_maxGroupUnits = (_maxGroupUnits max 1) min 24;

private _currentRecruits = 0;
{
    if (alive _x && { _x getVariable ["ARC_recruitedAI", false] }) then
    {
        _currentRecruits = _currentRecruits + 1;
    };
} forEach (units _callerGroup);

private _remaining = _maxGroupUnits - _currentRecruits;
if (_remaining <= 0) exitWith
{
    if (_owner > 0) then { ["Recruitment", format ["Recruitment cap reached (%1 AI).", _maxGroupUnits]] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};
private _spawnCount = _count min _remaining;

private _spawnGroup = createGroup [_side, true];
private _spawned = [];
for "_i" from 1 to _spawnCount do
{
    private _spawnPos = (getPosATL _container) getPos [4 + random 2, random 360];
    _spawnPos resize 3;
    _spawnPos set [2, 0];

    private _unit = _spawnGroup createUnit [_unitClass, _spawnPos, [], 0, "NONE"];
    if (isNull _unit) then
    {
        diag_log format ["[ARC][WARN] ARC_fnc_recruitSpawnRequest: createUnit failed class=%1", _unitClass];
        continue;
    };

    _unit setPosATL _spawnPos;
    [_unit] joinSilent _callerGroup;

    _unit setVariable ["ARC_recruitedAI", true, true];
    _unit setVariable ["ARC_recruitedByUid", getPlayerUID _caller, true];
    _unit setVariable ["ARC_recruitedByName", name _caller, true];
    _unit setVariable ["ARC_recruitContainerNetId", netId _container, true];
    _unit setVariable ["ARC_recruitSpawnedAt", serverTime, true];
    _spawned pushBack _unit;
};
deleteGroup _spawnGroup;

if ((count _spawned) <= 0) exitWith
{
    if (_owner > 0) then { ["Recruitment", "Unable to spawn that unit type."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

private _label = getText (_cfg >> "displayName");
if (_label isEqualTo "") then { _label = _unitClass; };

diag_log format ["[ARC][INFO] ARC_fnc_recruitSpawnRequest: spawned count=%1 class=%2 caller=%3 group=%4", count _spawned, _unitClass, name _caller, groupId _callerGroup];
if (_owner > 0) then { ["Recruitment", format ["%1 x %2 joined your group.", count _spawned, _label]] remoteExec ["ARC_fnc_clientToast", _owner]; };

true
