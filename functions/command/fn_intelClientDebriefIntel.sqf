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

params [
    ["_station", objNull],
    ["_caller", player],
    ["_forceConsole", false, [false]],
    ["_orderIdOverride", "", [""]]
];

if (isNull _caller || {!isPlayer _caller}) exitWith {false};

// Basic anti-spam lockout (local)
private _until = missionNamespace getVariable ["ARC_intelDebrief_lockUntil", 0];
if (!(_until isEqualType 0)) then { _until = 0; };
if (time < _until) exitWith {false};
missionNamespace setVariable ["ARC_intelDebrief_lockUntil", time + 3];

private _orderIdO = "";
if (_orderIdOverride isEqualType "") then { _orderIdO = trim _orderIdOverride; };

private _useOverride = false;

if (_orderIdO isNotEqualTo "") then
{
    // Override requires TOC authority and forceConsole mode (used by the Farabad Console).
    if (!_forceConsole) exitWith
    {
        hint "Cannot submit Intel Debrief for another unit without TOC console override.";
        false
    };

    private _canForce = [_caller] call ARC_fnc_rolesCanApproveQueue;
    if (!(_canForce isEqualType true)) then { _canForce = false; };

    if (!_canForce) exitWith
    {
        hint "TOC authorization required to submit Intel Debrief for another unit.";
        false
    };

    _useOverride = true;
}
else
{
    // Standard group-scoped debrief.
    if (!([_caller] call ARC_fnc_intelClientHasAcceptedRtbIntel)) exitWith
    {
        hint "No accepted RTB (INTEL) order for your group.";
        false
    };
};

private _defaultSummary = "Intel debrief delivered";
private _defaultDetails = "";

private _resp = ["DEBRIEF", _defaultSummary, _defaultDetails] call ARC_fnc_clientIntelPrompt;
_resp params ["_ok", "_sum", "_det"];
if (!_ok) exitWith {false};

[_caller, _sum, _det, _forceConsole, _orderIdO] remoteExec ["ARC_fnc_intelOrderCompleteRtbIntel", 2];
hint "Debrief submitted to TOC.";
true
