/*
    Client-side: prompt for a free-text intel report (summary + optional details).

    Params:
        0: STRING - category (e.g., "HUMINT", "SIGHTING", "ISR")
        1: STRING - default summary (optional)
        2: STRING - default details (optional)

    Returns:
        ARRAY [okBool, summaryText, detailsText]

    Notes:
    - Synchronous-only API: must be called from scheduled environment (canSuspend == true).
    - Uses ARC_IntelReportDialog defined in config\CfgDialogs.hpp.
    - Returned details may contain newlines; callers should convert to <br/> when rendering structured text.
*/

if (!hasInterface) exitWith {[false, "", ""]};

if (!canSuspend) exitWith {
    diag_log "[FARABAD][PROMPT][WARN] ARC_fnc_clientIntelPrompt requires scheduled execution (canSuspend == true).";
    [false, "", ""]
};

params [
    ["_category", "INTEL"],
    ["_defaultSummary", ""],
    ["_defaultDetails", ""]
];


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
uiNamespace setVariable ["ARC_intelDialog_category", toUpper _category];
uiNamespace setVariable ["ARC_intelDialog_defaultSummary", _defaultSummary];
uiNamespace setVariable ["ARC_intelDialog_defaultDetails", _defaultDetails];
uiNamespace setVariable ["ARC_intelDialog_result", nil];

// Open dialog
createDialog "ARC_IntelReportDialog";

// Wait until it closes or returns a result
waitUntil {
    uiSleep 0.05;
    (!isNil { uiNamespace getVariable "ARC_intelDialog_result" }) || { isNull (findDisplay 77001) }
};

private _res = uiNamespace getVariable ["ARC_intelDialog_result", [false, "", ""]];
uiNamespace setVariable ["ARC_intelDialog_result", nil];

// Normalize
_res params ["_ok", "_sum", "_det"];
if (!(_ok isEqualType true)) then { _ok = false; };
if (!(_sum isEqualType "")) then { _sum = ""; };
if (!(_det isEqualType "")) then { _det = ""; };

_sum = [_sum] call _trimFn;
_det = [_det] call _trimFn;

diag_log format ["[FARABAD][PROMPT][DONE] ok=%1", _ok];

[_ok, _sum, _det]
