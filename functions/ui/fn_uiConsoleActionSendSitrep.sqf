/*
    ARC_fnc_uiConsoleActionSendSitrep

    Client: invoked from the console "Send SITREP" button.

    Behavior:
      - Uses existing SITREP gating (role + proximity + close-ready)
      - Prefills recommendation from ARC_activeIncidentSuggestedResult when available

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// Fast UX gate: show a clear message before we open the text prompt.
if !([player] call ARC_fnc_clientCanSendSitrep) exitWith
{
    ["SITREP", "SITREP is not available yet. Ensure the incident is accepted, close-ready, and you are within range of the objective/lead/convoy."] call ARC_fnc_clientToast;
    false
};

private _rec = missionNamespace getVariable ["ARC_activeIncidentSuggestedResult", ""]; 
if (!(_rec isEqualType "")) then { _rec = ""; };
private _trimFn = compile "params ['_s']; trim _s";
_rec = toUpper ([_rec] call _trimFn);

// clientSendSitrep validates the recommendation itself.
[_rec, false] spawn ARC_fnc_clientSendSitrep;

true
