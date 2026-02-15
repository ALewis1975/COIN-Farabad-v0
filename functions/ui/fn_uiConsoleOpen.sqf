/*
    ARC_fnc_uiConsoleOpen

    Client: open the Farabad Console dialog.

    Access model:
      - Console can be opened from anywhere, but only if the unit carries
        an approved tablet item (see ARC_fnc_uiConsoleCanOpen).
      - Tabs/actions inside the console are gated by group-based roles.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _gate = [player] call ARC_fnc_uiConsoleCanOpen;
_gate params ["_ok", "_reason"];

if (!_ok) exitWith
{
    ["Farabad Console", _reason] call ARC_fnc_clientToast;
    false
};

// If already open, do nothing.
private _d = uiNamespace getVariable ["ARC_console_display", displayNull];
if (!isNull _d) exitWith {true};

createDialog "ARC_FarabadConsoleDialog";
true
