/*
    Client-side: log a sighting for whatever the player is currently looking at.

    This is a "low friction" way to create non-generic intel without typing.

    Behavior:
    - Uses cursorTarget as the observed object.
    - Builds a short summary from the object's displayName / unit name, speed, and direction.
    - Sends the report to the server to be persisted/broadcast.

    Returns:
        BOOL
*/

if (!hasInterface) exitWith {false};

private _tgt = cursorTarget;
if (isNull _tgt) exitWith { hint "No target under cursor."; false };

private _posATL = getPosATL _tgt;
private _grid = mapGridPosition _posATL;

private _class = typeOf _tgt;
private _dispName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
if (_dispName isEqualTo "") then { _dispName = _class; };

private _who = if (_tgt isKindOf "CAManBase") then { name _tgt } else { "" };
private _label = if (_who isEqualTo "") then { _dispName } else { format ["%1 (%2)", _who, _dispName] };

private _spd = round (speed _tgt);
private _dir = round (getDir _tgt);

private _sum = format ["Observed %1 at %2. Speed %3 kph, heading %4.", _label, _grid, _spd, _dir];

private _metaExtra = [
    ["observedClass", _class],
    ["observedName", _who],
    ["speedKph", str _spd],
    ["heading", str _dir]
];

[name player, "SIGHTING", _posATL, _sum, "", _metaExtra] remoteExec ["ARC_fnc_tocRequestLogIntel", 2];
hint format ["Submitted sighting: %1", _label];
true
