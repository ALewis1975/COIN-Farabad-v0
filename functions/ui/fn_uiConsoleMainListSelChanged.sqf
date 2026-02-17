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

private _tab = uiNamespace getVariable ["ARC_console_activeTab", "HANDOFF"];
if (!(_tab isEqualType "")) then { _tab = "HANDOFF"; };
_tab = toUpper _tab;

switch (_tab) do
{
    case "INTEL": { [_display, false] call ARC_fnc_uiConsoleIntelPaint; };
    case "HQ":    { [_display, false] call ARC_fnc_uiConsoleHQPaint; };
    case "CMD":
    {
        private _cmdMode = uiNamespace getVariable ["ARC_console_cmdMode", "OVERVIEW"];
        if ((_cmdMode isEqualType "") && { (toUpper (trim _cmdMode)) isEqualTo "QUEUE" }) then
        {
            uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", false];
            [_display, false] call ARC_fnc_uiConsoleTocQueuePaint;
            [_display] call ARC_fnc_uiConsoleRefresh;
        };
    };
    default
    {
        // no-op for other tabs
    };
};

true
