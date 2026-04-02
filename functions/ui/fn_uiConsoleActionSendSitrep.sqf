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
    // Read the cached reason code from the most recent gate evaluation.
    private _reasonCode = player getVariable ["ARC_sitrep_lastDenyReason", ""];
    if (!(_reasonCode isEqualType "")) then { _reasonCode = ""; };

    private _msg = switch (_reasonCode) do
    {
        case "E_NO_ACTIVE_INCIDENT":         { "No active incident." };
        case "E_INCIDENT_NOT_ACCEPTED":      { "Incident not yet accepted by your element." };
        case "E_STATE_NOT_READY_FOR_SITREP": { "Incident not close-ready. Mark COMPLETE first." };
        case "OK_IDEMPOTENT":               { "SITREP already submitted — awaiting TOC decision." };
        case "E_ROLE_NOT_AUTHORIZED":        { "Your role is not authorized to submit a SITREP." };
        case "E_AUTH_SCOPE_DENIED":          { "Not in range of the objective/lead/convoy position." };
        default                              { "SITREP not available. Check incident state and proximity." };
    };
    ["SITREP", _msg] call ARC_fnc_clientToast;
    false
};

private _rec = missionNamespace getVariable ["ARC_activeIncidentSuggestedResult", ""]; 
if (!(_rec isEqualType "")) then { _rec = ""; };
private _trimFn = compile "params ['_s']; trim _s";
_rec = toUpper ([_rec] call _trimFn);

// clientSendSitrep validates the recommendation itself.
[_rec, false] spawn ARC_fnc_clientSendSitrep;

true
