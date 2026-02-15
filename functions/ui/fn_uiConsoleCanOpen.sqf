/*
    ARC_fnc_uiConsoleCanOpen

    Client: return TRUE if the player can open the Farabad Console.

    Rule (default): must carry an approved "tablet" item.
    This makes the console feel like a real capability (cTab / Android / DAGR) and
    avoids giving every role an always-on admin panel.

    Overrides (missionNamespace):
      ARC_consoleNoItemRequired   : BOOL (default false)
      ARC_consoleRequiredItems    : ARRAY of STRING item classnames

    Params:
      0: OBJECT unit (optional, default player)

    Returns:
      ARRAY [BOOL canOpen, STRING reason]
*/

if (!hasInterface) exitWith {[false, "No interface"]};

params [
    ["_unit", player, [objNull]]
];

if (isNull _unit) exitWith {[false, "No unit"]};

// Dev override (debug)
private _noReq = missionNamespace getVariable ["ARC_consoleNoItemRequired", false];
if (!(_noReq isEqualType true)) then { _noReq = false; };
if (_noReq) exitWith {[true, ""]};

// 1) Inventory device check (open anywhere)
private _required = missionNamespace getVariable ["ARC_consoleRequiredItems", []];
if (!(_required isEqualType []) || { _required isEqualTo [] }) then
{
    // Defaults: cTab items + ACE DAGR (if present)
    _required = ["ItemcTab", "ItemAndroid", "ItemcTabHCam", "ItemMicroDAGR", "ACE_DAGR"];
};

private _inv = (items _unit) + (assignedItems _unit);
private _hasDevice = false;
{
    if (_x isEqualType "" && { _x in _inv }) exitWith { _hasDevice = true; };
} forEach _required;

if (_hasDevice) exitWith {[true, ""]};

// 2) Terminal proximity (TOC screens, debrief boards, etc.)
private _termVars = missionNamespace getVariable ["ARC_consoleTerminalVarNames", []];
if (!(_termVars isEqualType [])) then { _termVars = []; };

// Default proximity is intentionally tight to avoid "open from across the room" behavior.
private _termR = missionNamespace getVariable ["ARC_consoleTerminalRadiusM", 4];
if (!(_termR isEqualType 0)) then { _termR = 4; };

private _nearTerminal = false;
{
    if (!(_x isEqualType "")) then { continue; };
    private _obj = missionNamespace getVariable [_x, objNull];
    if (!isNull _obj && { (_unit distance _obj) <= _termR }) exitWith { _nearTerminal = true; };
} forEach _termVars;

if (_nearTerminal) exitWith {[true, ""]};

// 2b) Terminal proximity by object classname (robust fallback when editor objects aren't named)
private _termClasses = missionNamespace getVariable ["ARC_consoleTerminalClasses", []];
if (!(_termClasses isEqualType []) || { _termClasses isEqualTo [] }) then
{
    _termClasses = ["RuggedTerminal_01_communications_F","Land_Laptop_03_black_F","Land_Laptop_03_olive_F","Land_Laptop_02_unfolded_F","Land_Laptop_01_F","Land_Tablet_02_F"];
};

private _nearObjTerminal = false;
private _nearObjs = nearestObjects [_unit, _termClasses, _termR];
if (!isNil "_nearObjs" && { (count _nearObjs) > 0 }) then { _nearObjTerminal = true; };
if (_nearObjTerminal) exitWith {[true, ""]};

// 3) Marker fallback (if terminal objects are simpleObjects / not available client-side)
private _marks = missionNamespace getVariable ["ARC_consoleTerminalMarkers", []];
if (!(_marks isEqualType [])) then { _marks = []; };

private _markR = missionNamespace getVariable ["ARC_consoleTerminalMarkerRadiusM", 5];
if (!(_markR isEqualType 0)) then { _markR = 5; };

private _nearMark = false;
{
    if (!(_x isEqualType "")) then { continue; };
    if (!(_x in allMapMarkers)) then { continue; };
    if ((_unit distance2D (getMarkerPos _x)) <= _markR) exitWith { _nearMark = true; };
} forEach _marks;

if (_nearMark) exitWith {[true, ""]};

// 4) Mobile ops terminals (vehicles)
private _mobVars = missionNamespace getVariable ["ARC_consoleMobileTerminalVarNames", ["remote_ops_vehicle"]];
if (!(_mobVars isEqualType [])) then { _mobVars = ["remote_ops_vehicle"]; };

private _mobR = missionNamespace getVariable ["ARC_consoleMobileTerminalRadiusM", 5];
if (!(_mobR isEqualType 0)) then { _mobR = 5; };

private _veh = vehicle _unit;
if (!isNull _veh && { _veh != _unit } && { _veh getVariable ["ARC_isMobileTerminal", false] }) exitWith {[true, ""]};

private _nearMob = false;
{
    if (!(_x isEqualType "")) then { continue; };
    private _v = missionNamespace getVariable [_x, objNull];
    if (!isNull _v && { alive _v }) then
    {
        if (_veh isEqualTo _v || { (_unit distance _v) <= _mobR }) exitWith { _nearMob = true; };
    };
} forEach _mobVars;

if (_nearMob) exitWith {[true, ""]};

[false, "Requires a tablet (cTab/Android/DAGR) or use a TOC/mobile terminal."]
