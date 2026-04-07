/*
    ARC_fnc_uiConsoleMainListSelChanged

    Client: selection change handler for the console's secondary listbox (idc 78011).
    Used by tabs that present an interactive list (Workboard, S2 Ops, etc.).
*/

if (!hasInterface) exitWith {false};

params [
    ["_ctrl", controlNull, [controlNull]],
    ["_index", -1, [0]]
];

if (isNull _ctrl || { _index < 0 }) exitWith {false};

private _display = ctrlParent _ctrl;
if (isNull _display) exitWith {false};

private _tab = ["ARC_console_activeTab", "HANDOFF"] call ARC_fnc_uiNsGetString;
_tab = toUpper _tab;

if (_tab isEqualTo "AIR") then
{
    private _data = _ctrl lbData _index;
    if (!(_data isEqualType "")) then { _data = ""; };
    private _parts = _data splitString "|";
    private _kind = if ((count _parts) > 0) then { _parts select 0 } else { "" };

    uiNamespace setVariable ["ARC_console_airSelectedRow", _parts];
    uiNamespace setVariable ["ARC_console_airSelectedRowType", _kind];

    // Phase 7: recenter map on selected traffic position.
    if (_kind in ["ARR", "DEP"]) then {
        private _selFid = if ((count _parts) > 1) then { _parts select 1 } else { "" };
        if (!(_selFid isEqualTo "")) then {
            [_display, _selFid] call ARC_fnc_uiConsoleAirMapPaint;
        };
    };
};

switch (_tab) do
{
    case "INTEL": { [_display, false] call ARC_fnc_uiConsoleIntelPaint; };
    case "HQ":    { [_display, false] call ARC_fnc_uiConsoleHQPaint; };
    case "AIR":   { [_display, false] call ARC_fnc_uiConsoleAirPaint; };
    case "S1":    { [_display] call ARC_fnc_uiConsoleS1Paint; };
    case "CMD":
    {
        if (uiNamespace getVariable ["ARC_console_cmdQueuePainting", false]) exitWith {};
        private _cmdMode = ["ARC_console_cmdMode", "OVERVIEW"] call ARC_fnc_uiNsGetString;
        if ((_cmdMode isEqualType "") && { (toUpper (trim _cmdMode)) isEqualTo "QUEUE" }) then
        {
            uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", false];
            [_display, false] call ARC_fnc_uiConsoleTocQueuePaint;
        };
    };
    default
    {
        // no-op for other tabs
    };
};

true
