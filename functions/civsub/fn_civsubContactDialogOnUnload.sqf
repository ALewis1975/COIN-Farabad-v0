/*
    ARC_fnc_civsubContactDialogOnUnload

    Client-side: ends the interaction session on the server.

    Behavior:
      - Always calls ARC_fnc_civsubInteractEndSession.
      - The server decides whether to restore movement (won't restore if detained).
*/
if (!hasInterface) exitWith { true };

uiNamespace setVariable ["ARC_civsubInteract_watchStop", true];

private _civ = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
uiNamespace setVariable ["ARC_civsubInteract_target", objNull];

if (!isNull _civ) then {
    // End-session for dialog use should be silent (no chat spam).
    [_civ, player, true] remoteExecCall ["ARC_fnc_civsubInteractEndSession", 2];
};
