/*
    ARC_fnc_intelClientProcessEpw

    Client: process EPWs at the SHERIFF handling / EPW processing station
    to complete an accepted RTB(EPW) order.

    Intended to be called from an addAction on:
      - sheriff_handling unit (preferred)
      - EPW processing building object (EPW_Porcessing / EPW_Processing)

    Params:
      0: OBJECT - station (optional)
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

// Local anti-spam lockout
private _until = missionNamespace getVariable ["ARC_epwProcess_lockUntil", 0];
if (!(_until isEqualType 0)) then { _until = 0; };
if (time < _until) exitWith {false};
missionNamespace setVariable ["ARC_epwProcess_lockUntil", time + 3];

private _orderIdO = "";
if (_orderIdOverride isEqualType "") then { _orderIdO = trim _orderIdOverride; };

private _useOverride = false;

if (_orderIdO isNotEqualTo "") then
{
    // Override requires TOC authority and forceConsole mode (used by the Farabad Console).
    if (!_forceConsole) exitWith
    {
        hint "Cannot process EPW for another unit without TOC console override.";
        false
    };

    private _canForce = [_caller] call ARC_fnc_rolesCanApproveQueue;
    if (!(_canForce isEqualType true)) then { _canForce = false; };

    if (!_canForce) exitWith
    {
        hint "TOC authorization required to process EPW for another unit.";
        false
    };

    _useOverride = true;
}
else
{
    // Standard group-scoped processing.
    if (!([_caller] call ARC_fnc_intelClientHasAcceptedRtbEpw)) exitWith
    {
        hint "No accepted RTB (EPW) order for your group.";
        false
    };
};

private _defaultSummary = "EPW processed and transferred to holding";
private _defaultDetails = "";

private _resp = ["EPW", _defaultSummary, _defaultDetails] call ARC_fnc_clientIntelPrompt;
_resp params ["_ok", "_sum", "_det"]; 
if (!_ok) exitWith {false};

[_caller, _sum, _det, _forceConsole, _orderIdO] remoteExec ["ARC_fnc_intelOrderCompleteRtbEpw", 2];
hint "EPW processing submitted.";
true
