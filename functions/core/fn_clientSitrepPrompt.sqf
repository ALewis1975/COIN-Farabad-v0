/*
    ARC_fnc_clientSitrepPrompt

    Client: open the structured SITREP dialog and return user input.

    Params:
      0: STRING - header HTML (optional)
      1: STRING - default summary (optional)
      2: STRING - default enemy/situation (optional)
      3: STRING - default friendly actions (optional)
      4: STRING - default task status (optional)
      5: ARRAY  - default ACE indices [ammo,cas,eq] (0..2)
      6: STRING - default requests (optional)
      7: STRING - default notes (optional)

    Returns:
      ARRAY - [ok, summary, enemy, friendly, taskStatus, aceAmmo, aceCas, aceEq, requests, notes]
*/

if (!hasInterface) exitWith { [false, "", "", "", "", "", "", "", "", ""] };

// Dialog waitUntil requires scheduled execution
if (!canSuspend) exitWith { _this spawn ARC_fnc_clientSitrepPrompt; [false, "", "", "", "", "", "", "", "", ""] };

params [
    ["_header", "", [""]],
    ["_sum", "", [""]],
    ["_enemy", "", [""]],
    ["_friendly", "", [""]],
    ["_task", "", [""]],
    ["_aceIdx", [0,0,0], [[]]],
    ["_req", "", [""]],
    ["_notes", "", [""]]
];

uiNamespace setVariable ["ARC_sitrepDialog_header", _header];
uiNamespace setVariable ["ARC_sitrepDialog_defaultSummary", _sum];
uiNamespace setVariable ["ARC_sitrepDialog_defaultEnemy", _enemy];
uiNamespace setVariable ["ARC_sitrepDialog_defaultFriendly", _friendly];
uiNamespace setVariable ["ARC_sitrepDialog_defaultTask", _task];
uiNamespace setVariable ["ARC_sitrepDialog_defaultRequests", _req];
uiNamespace setVariable ["ARC_sitrepDialog_defaultNotes", _notes];
uiNamespace setVariable ["ARC_sitrepDialog_defaultACE", _aceIdx];
uiNamespace setVariable ["ARC_sitrepDialog_result", nil];

createDialog "ARC_SitrepDialog";

waitUntil {
    uiSleep 0.05;
    !isNil { uiNamespace getVariable "ARC_sitrepDialog_result" }
};

private _res = uiNamespace getVariable ["ARC_sitrepDialog_result", [false, "", "", "", "", "", "", "", "", ""]];
_res
