/*
    ARC_fnc_uiConsoleActionCloseIncident

    Client: invoked from the console Closeout tab.

    Purpose:
      - Close the currently active incident via UI (no addAction dependency).
      - Preserve TOC authority: only S3/Command (queue approvers) or OMNI can close.
      - Provide a confirmation prompt and clear operator feedback.

    Params:
      0: STRING - result ("SUCCEEDED" or "FAILED")

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI button handlers run in an unscheduled environment. BIS_fnc_guiMessage requires scheduled execution.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionCloseIncident; false };

params [
    ["_result", "", [""]]
];

_result = toUpper (trim _result);
if !(_result in ["SUCCEEDED", "FAILED"]) exitWith
{
    ["Closeout", "Invalid close result."] call ARC_fnc_clientToast;
    false
};

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canApprove = _isOmni || { [player] call ARC_fnc_rolesCanApproveQueue };
if (!_canApprove) exitWith
{
    ["Closeout", "Restricted to TOC approvers (S3/Command) or OMNI."] call ARC_fnc_clientToast;
    false
};

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (_taskId isEqualTo "") exitWith
{
    ["Closeout", "No active incident to close."] call ARC_fnc_clientToast;
    false
};

private _disp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Incident"];
if (!(_disp isEqualType "")) then { _disp = "Incident"; };

private _type = missionNamespace getVariable ["ARC_activeIncidentType", ""];
if (!(_type isEqualType "")) then { _type = ""; };
private _typeU = toUpper _type;

private _pos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
if (!(_pos isEqualType [])) then { _pos = []; };
private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "" };

private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

private _sug = missionNamespace getVariable ["ARC_activeIncidentSuggestedResult", ""];
if (!(_sug isEqualType "")) then { _sug = ""; };
_sug = toUpper _sug;

private _reason = missionNamespace getVariable ["ARC_activeIncidentCloseReason", ""];
if (!(_reason isEqualType "")) then { _reason = ""; };
_reason = toUpper _reason;

// Locked rule: any CIV KIA from detonation blocks SUCCESS closure.
// Client side: block the action for clarity. Server side also enforces.
private _civKia = missionNamespace getVariable ["ARC_activeIedCivKia", 0];
if (!(_civKia isEqualType 0)) then { _civKia = 0; };
if (_result isEqualTo "SUCCEEDED" && { _typeU isEqualTo "IED" } && { _civKia > 0 }) exitWith
{
    ["Closeout", format ["Civilian KIA detected (%1). Closeout MUST be FAILED.", _civKia]] call ARC_fnc_clientToast;
    false
};

private _title = if (_closeReady) then {"Close Active Incident"} else {"FORCE Close Active Incident"};

private _lines = [];
_lines pushBack format ["Task: %1", _taskId];
_lines pushBack format ["Incident: %1%2", _disp, if (_typeU isEqualTo "") then {""} else {format [" (%1)", _typeU]}];
if (_grid isNotEqualTo "") then { _lines pushBack format ["Location: %1", _grid]; };
if (_sug in ["SUCCEEDED","FAILED"]) then { _lines pushBack format ["Suggested: %1", _sug]; };
if (_reason isNotEqualTo "") then { _lines pushBack format ["Reason: %1", _reason]; };

_lines pushBack "";
_lines pushBack format ["Close as: %1", _result];

if (!_closeReady) then
{
    _lines pushBack "";
    _lines pushBack "WARNING: Incident is not close-ready.";
    _lines pushBack "Use force close only for QA or recovery.";
};

private _msg = _lines joinString "\n";
private _ok = [_msg, _title, true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

// Send to server (server validates authority and enforces any forced outcome rules).
[_result, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2];

["Closeout", format ["Close request submitted: %1", _result]] call ARC_fnc_clientToast;
true
