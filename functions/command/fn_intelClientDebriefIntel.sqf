/*
    ARC_fnc_intelClientDebriefIntel

    Client: submit an Intel Debrief at the TOC station to complete an accepted RTB(INTEL) order.

    Intended to be called from an addAction on the Intel Debrief station object.

    Params:
      0: OBJECT - debrief station (optional)
      1: OBJECT - caller (default: player)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!canSuspend) exitWith { _this spawn ARC_fnc_intelClientDebriefIntel; false };

params [
    ["_station", objNull],
    ["_caller", player],
    ["_forceConsole", false, [false]],
    ["_orderIdOverride", "", [""]]
];

if (isNull _caller || {!isPlayer _caller}) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

// Basic anti-spam lockout (local)
private _until = missionNamespace getVariable ["ARC_intelDebrief_lockUntil", 0];
if (!(_until isEqualType 0)) then { _until = 0; };
if (time < _until) exitWith {false};
missionNamespace setVariable ["ARC_intelDebrief_lockUntil", time + 3];

private _orderIdO = "";
if (_orderIdOverride isEqualType "") then { _orderIdO = [_orderIdOverride] call _trimFn; };

private _useOverride = false;

if (!(_orderIdO isEqualTo "")) then
{
    // Override requires TOC authority and forceConsole mode (used by the Farabad Console).
    if (!_forceConsole) exitWith
    {
        ["Use the TOC console override to submit an Intel Debrief for another unit.", "ACTION_REQUIRED", "HINT"] call ARC_fnc_clientHint;
        false
    };

    private _canForce = [_caller] call ARC_fnc_rolesCanApproveQueue;
    if (!(_canForce isEqualType true)) then { _canForce = false; };

    if (!_canForce) exitWith
    {
        ["TOC authorization required to submit an Intel Debrief for another unit.", "WARN", "TOAST"] call ARC_fnc_clientHint;
        false
    };

    _useOverride = true;
}
else
{
    // Standard group-scoped debrief.
    if (!([_caller] call ARC_fnc_intelClientHasAcceptedRtbIntel)) exitWith
    {
        ["No accepted RTB (INTEL) order for your group.", "WARN", "TOAST"] call ARC_fnc_clientHint;
        false
    };
};

private _defaultSummary = "Intel debrief delivered";
private _defaultDetails = "";

private _resp = ["DEBRIEF", _defaultSummary, _defaultDetails] call ARC_fnc_clientIntelPrompt;
_resp params ["_ok", "_sum", "_det"];
if (!_ok) exitWith {false};

[_caller, _sum, _det, _forceConsole, _orderIdO] remoteExec ["ARC_fnc_intelOrderCompleteRtbIntel", 2];
["Debrief submitted to TOC.", "INFO", "TOAST"] call ARC_fnc_clientHint;
true
