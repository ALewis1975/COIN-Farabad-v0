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

private _atConsole = [player] call ARC_fnc_uiConsoleIsAtStation;
if (_atConsole) then
{
    uiNamespace setVariable ["ARC_console_forceTab", "INTEL"];
    [] call ARC_fnc_uiConsoleOpen;
    ["CIVSUB", "Interaction routed to Farabad Console (S2/INTEL)."] call ARC_fnc_clientToast;
};

if (!isNull (findDisplay 78300)) exitWith {true}; // already open

uiNamespace setVariable ["ARC_civsubInteract_target", _civ];
if (!_atConsole) then { createDialog "ARC_CivsubInteractDialog"; };

// Request authoritative snapshot from server to populate header + enable/disable actions
[_civ, player] remoteExecCall ["ARC_fnc_civsubContactReqSnapshot", 2];
true
