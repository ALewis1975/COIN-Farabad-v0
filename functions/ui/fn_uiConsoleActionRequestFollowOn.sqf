/*
    ARC_fnc_uiConsoleActionRequestFollowOn

    Client: invoked from the console "Request Follow-on" button.

    Uses the existing command layer:
      - ARC_fnc_intelClientCanRequestFollowOn
      - ARC_fnc_intelClientRequestFollowOn

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// Uses ARC_fnc_uiFollowOnPrompt (createDialog + waitUntil). Ensure scheduled execution.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionRequestFollowOn; false };

// UI11+ workflow change: Follow-on requests are captured within the SITREP wizard to avoid deadlocks and duplicate submissions.
if (true) exitWith {
    ["SITREP", "Follow-on requests are now collected as part of the SITREP submission flow. Use Send SITREP to request follow-on."] call ARC_fnc_clientToast;
    false
};


if (!(call ARC_fnc_intelClientCanRequestFollowOn)) exitWith
{
    ["SITREP", "Follow-on request is not available (SITREP required, and no pending TOC order may be waiting for acceptance)."] call ARC_fnc_clientToast;
    false
};

private _sel = call ARC_fnc_uiFollowOnPrompt;
_sel params ["_ok", "_req", "_purpose", "_rat", "_con", "_sup", "_notes", "_holdIntent", "_holdMinutes", "_proceedIntent"];
if (!_ok) exitWith {false};
[_req, _purpose, _rat, _con, _sup, _notes, _holdIntent, _holdMinutes, _proceedIntent] spawn ARC_fnc_intelClientRequestFollowOn;

true
