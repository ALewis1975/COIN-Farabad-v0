/*
    ARC_fnc_uiEodDispoPrompt

    Client: prompt user for an EOD disposition request.

    Returns:
      ARRAY [okBool, requestType, notes]

    requestType:
      DET_IN_PLACE | RTB_IED | TOW_VBIED
*/

if (!hasInterface) exitWith { [false] };

if (!canSuspend) exitWith {
    private _args = if (_this isEqualType []) then { +_this } else { [] };
    _args pushBack true;
    _args spawn ARC_fnc_uiEodDispoPrompt;
    [false]
};

params [
    ["_spawnReentry", false]
];

if (_spawnReentry) then {
    diag_log "[FARABAD][PROMPT][SPAWN] reentered scheduled";
};

uiNamespace setVariable ["ARC_eodDispo_result", nil];

createDialog "ARC_EodDispoDialog";

waitUntil {
    uiSleep 0.05;
    (!isNil { uiNamespace getVariable "ARC_eodDispo_result" }) || { isNull (findDisplay 78250) }
};

private _res = uiNamespace getVariable ["ARC_eodDispo_result", [false]];
uiNamespace setVariable ["ARC_eodDispo_result", nil];

if (!(_res isEqualType [])) exitWith {
    diag_log "[FARABAD][PROMPT][DONE] ok=false";
    [false]
};

private _ok = _res param [0, false, [true]];
diag_log format ["[FARABAD][PROMPT][DONE] ok=%1", _ok];

_res
