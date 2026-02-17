/*
    ARC_fnc_uiConsoleActionToggleTaskingAvailability

    Client: toggle this player's group availability for TOC tasking.
*/

if (!hasInterface) exitWith {false};
if !([player] call ARC_fnc_rolesIsAuthorized) exitWith {false};

private _gid = groupId (group player);
if (_gid isEqualTo "") exitWith {false};

private _availRows = missionNamespace getVariable ["ARC_pub_groupTaskingAvailability", []];
if (!(_availRows isEqualType [])) then { _availRows = []; };
private _idx = _availRows findIf {
    (_x isEqualType []) && { (count _x) >= 2 } &&
    { ((_x # 0) isEqualType "") && { (toUpper (_x # 0)) isEqualTo (toUpper _gid) } }
};

private _isAvailable = true;
if (_idx >= 0) then { _isAvailable = (_availRows # _idx) param [1, true]; };
private _newAvailability = !_isAvailable;

[player, _newAvailability] remoteExecCall ["ARC_fnc_intelSetGroupTaskingAvailability", 2];
["Tasking", format ["%1 is now %2 for TOC tasking.", _gid, if (_newAvailability) then {"AVAILABLE"} else {"OFFLINE"}]] call ARC_fnc_clientToast;
true
