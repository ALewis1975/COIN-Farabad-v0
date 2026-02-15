/*
    ARC_fnc_uiConsoleIsAtStation

    Client helper: returns TRUE if the unit is physically at a TOC terminal
    or a mobile terminal (vehicle), regardless of tablet possession.

    Used for "view-only" TOC Ops access for authorized leadership.
*/

if (!hasInterface) exitWith {false};

params [["_unit", player, [objNull]]];
if (isNull _unit) exitWith {false};

// Terminal objects (Eden var names)
private _termVars = missionNamespace getVariable ["ARC_consoleTerminalVarNames", []];
if (!(_termVars isEqualType [])) then { _termVars = []; };
private _termR = missionNamespace getVariable ["ARC_consoleTerminalRadiusM", 4];
if (!(_termR isEqualType 0)) then { _termR = 4; };
_termR = (_termR max 1) min 15;

// Marker fallback (TOC area)
private _marks = missionNamespace getVariable ["ARC_consoleTerminalMarkers", []];
if (!(_marks isEqualType [])) then { _marks = []; };
private _markR = missionNamespace getVariable ["ARC_consoleTerminalMarkerRadiusM", 5];
if (!(_markR isEqualType 0)) then { _markR = 5; };
_markR = (_markR max 1) min 50;

// Mobile terminal vehicle(s)
private _mobVars = missionNamespace getVariable ["ARC_consoleMobileTerminalVarNames", ["remote_ops_vehicle"]];
if (!(_mobVars isEqualType [])) then { _mobVars = ["remote_ops_vehicle"]; };
private _mobR = missionNamespace getVariable ["ARC_consoleMobileTerminalRadiusM", 5];
if (!(_mobR isEqualType 0)) then { _mobR = 5; };
_mobR = (_mobR max 1) min 50;

// 1) Terminal object proximity
{
    if (!(_x isEqualType "")) then { continue; };
    private _obj = missionNamespace getVariable [_x, objNull];
    if (!isNull _obj && { (_unit distance _obj) <= _termR }) exitWith { true };
} forEach _termVars;

// 2) Marker proximity
{
    if (!(_x isEqualType "")) then { continue; };
    if (markerType _x isEqualTo "") then { continue; };
    private _p = getMarkerPos _x;
    if ((_unit distance2D _p) <= _markR) exitWith { true };
} forEach _marks;

// 3) Mobile terminal proximity / in-vehicle
private _veh = vehicle _unit;
if (!isNull _veh && { _veh != _unit } && { _veh getVariable ["ARC_isMobileTerminal", false] }) exitWith { true };

{
    if (!(_x isEqualType "")) then { continue; };
    private _v = missionNamespace getVariable [_x, objNull];
    if (isNull _v) then { continue; };
    if (!alive _v) then { continue; };

    if (_veh isEqualTo _v) exitWith { true };
    if ((_unit distance _v) <= _mobR) exitWith { true };
} forEach _mobVars;

false
