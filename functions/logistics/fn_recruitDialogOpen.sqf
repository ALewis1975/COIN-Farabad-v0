/*
    ARC_fnc_recruitDialogOpen

    Client: open the AI recruitment dialog for the selected recruitment object.

    Params:
      0: OBJECT recruitment object

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_container", objNull, [objNull]]
];

if (isNull _container) exitWith {false};

uiNamespace setVariable ["ARC_recruitDialog_container", _container];
uiNamespace setVariable ["ARC_recruitDialog_status", ""];

private _display = findDisplay 78400;
if (isNull _display) then
{
    createDialog "ARC_RecruitDialog";
    _display = findDisplay 78400;
    if (isNull _display) exitWith
    {
        diag_log "[ARC][WARN][RECRUIT] ARC_fnc_recruitDialogOpen: createDialog failed";
        false
    };
}
else
{
    [_display] call ARC_fnc_recruitDialogOnLoad;
};

true
