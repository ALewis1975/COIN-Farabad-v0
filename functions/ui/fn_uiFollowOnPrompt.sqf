/*
    ARC_fnc_uiFollowOnPrompt

    Client: prompt the player to submit a structured follow-on request.

    Returns:
      ARRAY [
        okBool,
        request,        // RTB|HOLD|PROCEED
        purpose,        // REFIT|INTEL|EPW (RTB only)
        rationale,
        constraints,
        support,
        notes,
        holdIntent,
        holdMinutes,
        proceedIntent
      ]
*/

if (!hasInterface) exitWith { [false] };

if (!canSuspend) exitWith {
    [] spawn {
        diag_log "[FARABAD][PROMPT][SPAWN] reentered scheduled";
        call ARC_fnc_uiFollowOnPrompt;
    };
    [false]
};

uiNamespace setVariable ["ARC_followOn_result", nil];

// Open dialog (defined in config/CfgDialogs.hpp)
createDialog "ARC_FollowOnDialog";

// Wait until user submits/cancels
waitUntil {
    uiSleep 0.05;
    (!isNil { uiNamespace getVariable "ARC_followOn_result" }) || { isNull (findDisplay 78100) }
};

private _res = uiNamespace getVariable ["ARC_followOn_result", [false]];
uiNamespace setVariable ["ARC_followOn_result", nil];

if (!(_res isEqualType [])) exitWith {
    diag_log "[FARABAD][PROMPT][DONE] ok=false";
    [false]
};

private _ok = _res param [0, false, [true]];
if (!_ok) exitWith {
    diag_log format ["[FARABAD][PROMPT][DONE] ok=%1", _ok];
    [false]
};

diag_log format ["[FARABAD][PROMPT][DONE] ok=%1", _ok];

_res
