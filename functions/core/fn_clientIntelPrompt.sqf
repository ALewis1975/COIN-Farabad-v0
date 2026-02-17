/*
    Client-side: prompt for a free-text intel report (summary + optional details).

    Params:
        0: STRING - category (e.g., "HUMINT", "SIGHTING", "ISR")
        1: STRING - default summary (optional)
        2: STRING - default details (optional)

    Returns:
        ARRAY [okBool, summaryText, detailsText]

    Notes:
    - Uses ARC_IntelReportDialog defined in config\CfgDialogs.hpp.
    - Returned details may contain newlines; callers should convert to <br/> when rendering structured text.
*/

if (!hasInterface) exitWith {[false, "", ""]};

if (!canSuspend) exitWith {
    private _args = if (_this isEqualType []) then { +_this } else { [] };
    _args pushBack true;
    _args spawn ARC_fnc_clientIntelPrompt;
    [false, "", ""]
};

params [
    ["_category", "INTEL"],
    ["_defaultSummary", ""],
    ["_defaultDetails", ""],
    ["_spawnReentry", false]
];

if (_spawnReentry) then {
    diag_log "[FARABAD][PROMPT][SPAWN] reentered scheduled";
};

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

_sum = trim _sum;
_det = trim _det;

diag_log format ["[FARABAD][PROMPT][DONE] ok=%1", _ok];

[_ok, _sum, _det]
