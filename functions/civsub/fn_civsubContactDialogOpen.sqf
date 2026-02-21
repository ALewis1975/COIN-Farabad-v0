/*
    ARC_fnc_civsubContactDialogOpen

    Client-side: Opens the CIVSUB Interact dialog (Step 2 UI shell).

    Params:
      0: civ unit (object)
*/
if (!hasInterface) exitWith {false};

params [
    ["_civ", objNull, [objNull]]
];
if (isNull _civ) exitWith {false};

uiNamespace setVariable ["ARC_civsubInteract_target", _civ];
uiNamespace setVariable ["ARC_console_forceTab", "INTEL"];
private _console = findDisplay 78000;
if (isNull _console) then
{
    private _opened = [] call ARC_fnc_uiConsoleOpen;
    if (!_opened) exitWith
    {
        // Console failed to open (no tablet/terminal access) — clear interaction state so
        // stale context doesn't persist across the failed session.
        uiNamespace setVariable ["ARC_civsubInteract_target", objNull];
        uiNamespace setVariable ["ARC_console_forceTab", nil];
        false
    };
    ["CIVSUB", "Interaction routed to Farabad Console (S2/INTEL)."] call ARC_fnc_clientToast;
}
else
{
    uiNamespace setVariable ["ARC_console_activeTab", "INTEL"];
    [_console] call ARC_fnc_uiConsoleRefresh;
};

// Request authoritative snapshot from server to populate header + enable/disable actions
[_civ, player] remoteExecCall ["ARC_fnc_civsubContactReqSnapshot", 2];
true
