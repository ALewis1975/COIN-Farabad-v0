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

if (!isNull (findDisplay 78300)) exitWith {true}; // already open

uiNamespace setVariable ["ARC_civsubInteract_target", _civ];
createDialog "ARC_CivsubInteractDialog";

// Request authoritative snapshot from server to populate header + enable/disable actions
[_civ, player] remoteExecCall ["ARC_fnc_civsubContactReqSnapshot", 2];
true
