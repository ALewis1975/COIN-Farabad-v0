/*
    Client-side snapshot refresh helper for briefing/TOC rehydration.
    Called by initPlayerLocal watcher polling and PV event handlers.
*/

if (!hasInterface) exitWith { false };
if (isNil "ARC_fnc_briefingUpdateClient") exitWith
{
    diag_log "[ARC][WARN] ARC_fnc_clientSnapshotRefresh: ARC_fnc_briefingUpdateClient missing; refresh skipped.";
    false
};

private _debounceIntervalSec = 1;
// Debounce: skip if a refresh already ran within the configured interval.
private _pendingAt = uiNamespace getVariable ["ARC_clientSnapshotRefreshPendingAt", -1];
if (!(_pendingAt isEqualType 0)) then { _pendingAt = -1; };
private _now = diag_tickTime;
if ((_now - _pendingAt) < _debounceIntervalSec) exitWith { false };
uiNamespace setVariable ["ARC_clientSnapshotRefreshPendingAt", _now];

[] call ARC_fnc_briefingUpdateClient;
if (!isNil "ARC_fnc_tocRefreshClient") then { [] call ARC_fnc_tocRefreshClient; };
uiNamespace setVariable ["ARC_console_dirty", true];

private _refreshCount = uiNamespace getVariable ["ARC_clientSnapshotRefreshCount", 0];
if (!(_refreshCount isEqualType 0)) then { _refreshCount = 0; };
uiNamespace setVariable ["ARC_clientSnapshotRefreshCount", _refreshCount + 1];
true
