/*
    ARC_fnc_uiConsoleActionIntelLog

    Client: prompt for an intel note and send it to the server for persistence.

    Default behavior:
      - Category: HUMINT (override via missionNamespace ARC_consoleIntelDefaultCategory)
      - Location: player's current position

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
// UI event handlers are unscheduled; dialogs require scheduled context.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionIntelLog; false };

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canLog = _isOmni
    || { [player] call ARC_fnc_rolesIsAuthorized }
    || { [player] call ARC_fnc_rolesIsTocS2 }
    || { [player] call ARC_fnc_rolesIsTocS3 }
    || { [player] call ARC_fnc_rolesIsTocCommand };

if (!_canLog) exitWith
{
    ["Intel", "Not authorized to log intel."] call ARC_fnc_clientToast;
    false
};

private _cat = missionNamespace getVariable ["ARC_consoleIntelDefaultCategory", "HUMINT"];
if (!(_cat isEqualType "")) then { _cat = "HUMINT"; };
_cat = toUpper ([_cat] call _trimFn);
if (_cat isEqualTo "") then { _cat = "HUMINT"; };

private _reporter = [player] call ARC_fnc_rolesFormatUnit;
private _posATL = getPosATL player;

// Prep dialog defaults
uiNamespace setVariable ["ARC_intelDialog_category", _cat];
uiNamespace setVariable ["ARC_intelDialog_defaultSummary", ""]; 
uiNamespace setVariable ["ARC_intelDialog_defaultDetails", ""]; 
uiNamespace setVariable ["ARC_intelDialog_result", nil];

createDialog "ARC_IntelReportDialog";

waitUntil
{
    uiSleep 0.10;
    !isNil { uiNamespace getVariable "ARC_intelDialog_result" }
        || { isNull (uiNamespace getVariable ["ARC_intelDialog_display", displayNull]) }
};

private _res = ["ARC_intelDialog_result", [false, "", ""]] call ARC_fnc_uiNsGetArray;
uiNamespace setVariable ["ARC_intelDialog_result", nil];

if (!(_res isEqualType [] && { (count _res) >= 3 })) exitWith
{
    ["Intel", "Intel dialog failed."] call ARC_fnc_clientToast;
    false
};

_res params ["_ok", "_summary", "_details"];
if (!_ok) exitWith
{
    ["Intel", "Canceled."] call ARC_fnc_clientToast;
    false
};

_summary = [_summary] call _trimFn;
_details = [_details] call _trimFn;

if (_summary isEqualTo "") exitWith
{
    ["Intel", "Summary required."] call ARC_fnc_clientToast;
    false
};

private _metaExtra = [
    ["source", "UI_CONSOLE"],
    ["group", groupId (group player)],
    ["event", "UI_INTEL_LOG"]
];

[player, _reporter, _cat, _posATL, _summary, _details, _metaExtra] remoteExec ["ARC_fnc_tocRequestLogIntel", 2];

["Intel", "Submitted intel report."] call ARC_fnc_clientToast;

// Helpful in hosted/SP where JIP broadcast timing can be funky.
[] remoteExec ["ARC_fnc_tocRequestRefreshIntel", 2];

true
