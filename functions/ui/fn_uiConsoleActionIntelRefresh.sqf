/*
    ARC_fnc_uiConsoleActionIntelRefresh

    Client: request a server refresh broadcast of intel/state snapshots.

    Throttled to avoid spam.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI event handlers are unscheduled; keep this scheduled-friendly.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionIntelRefresh; false };

private _last = uiNamespace getVariable ["ARC_console_lastIntelRefreshAt", -1000];
if (!(_last isEqualType 0)) then { _last = -1000; };

private _now = diag_tickTime;
if ((_now - _last) < 2) exitWith
{
    ["Intel", "Refresh throttled."] call ARC_fnc_clientToast;
    false
};

uiNamespace setVariable ["ARC_console_lastIntelRefreshAt", _now];

[] remoteExec ["ARC_fnc_tocRequestRefreshIntel", 2];
["Intel", "Refresh requested."] call ARC_fnc_clientToast;
true
