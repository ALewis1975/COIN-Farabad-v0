/*
    ARC_fnc_tocRequestCloseIncident

    Server: stage closeout for the active incident from the TOC (Console "Close Incident" action).

    New rule:
      - TOC closeout does NOT immediately close the incident.
      - TOC closeout MUST be paired with a TOC order that the assigned unit accepts.
      - The incident closes only after the unit accepts that order.

    This function is the "quick close" path (no detailed follow-on fields).
    It issues a default HOLD (15 min) if no ISSUED order exists; otherwise it reuses
    the existing ISSUED order for the assigned group.

    Params:
      0: STRING - "SUCCEEDED" | "FAILED" | "CANCELED"

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_result", "", [""]],
    // Optional:
    //   OBJECT (requestor) -> normal TOC closeout staging path
    //   BOOL true          -> FORCE close immediately (HQ/Admin override)
    ["_arg2", objNull, [objNull, false]],
    // Optional: explicit caller object (preferred over remoteExecutedOwner)
    ["_callerParam", objNull, [objNull]]
];

private _force = false;
private _requestor = objNull;
if (_arg2 isEqualType true) then { _force = _arg2; } else { _requestor = _arg2; };


// Normalize + validate
_result = toUpper (trim _result);
if !(_result in ["SUCCEEDED", "FAILED", "CANCELED"]) exitWith {false};

// Identify caller (prefer explicit)
private _caller = objNull;

if (!isNull _callerParam) then { _caller = _callerParam; };
if (isNull _caller && { !isNull _requestor }) then { _caller = _requestor; };

if (isNull _caller && { !isNil "remoteExecutedOwner" }) then
{
    {
        if (owner _x == remoteExecutedOwner) exitWith { _caller = _x; };
    } forEach allPlayers;
};

private _callerName = if (isNull _caller) then {"<unknown>"} else { name _caller };

// Authorization
private _callerOk = false;
if (!isNull _caller) then
{
    private _isOmni = [_caller, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    _callerOk = _isOmni || ([_caller] call ARC_fnc_rolesCanApproveQueue);
};
if (!_callerOk) exitWith
{
    diag_log format ["[ARC][TOC] CloseIncident rejected (unauthorized). caller=%1 result=%2", _callerName, _result];
    false
};


// HQ/Admin override: force close immediately (bypasses closeout-pending acceptance gating).
if (_force) exitWith
{
    diag_log format ["[ARC][TOC] FORCE CloseIncident: caller=%1 result=%2", _callerName, _result];
    [_result] call ARC_fnc_incidentClose;
};
// Guard: do not allow double-closeout while pending acceptance
private _pending = ["activeIncidentClosePending", false] call ARC_fnc_stateGet;
if (!(_pending isEqualType true)) then { _pending = false; };
if (_pending) exitWith
{
    diag_log format ["[ARC][TOC] CloseIncident denied (already pending). caller=%1", _callerName];
    false
};

// Require SITREP for the active incident (keeps loop honest)
private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };
if (!_sitrepSent) exitWith
{
    diag_log format ["[ARC][TOC] CloseIncident denied (no SITREP yet). caller=%1", _callerName];
    false
};

// Active context
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_taskId isEqualType "")) then { _taskId = ""; };
_taskId = trim _taskId;

if (_taskId isEqualTo "") then
{
    [] call ARC_fnc_taskRehydrateActive;
    _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (!(_taskId isEqualType "")) then { _taskId = ""; };
    _taskId = trim _taskId;
};

// Determine the assigned group.
// Farabad rule: issue/hand follow-on to the unit that SENT the SITREP.
// Fallbacks: accepted-by group (if no SITREP), lastTaskingGroup (last resort).
private _gidSitrep = ["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateGet;
if (!(_gidSitrep isEqualType "")) then { _gidSitrep = ""; };
_gidSitrep = trim _gidSitrep;

private _gidAccepted = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (!(_gidAccepted isEqualType "")) then { _gidAccepted = ""; };
_gidAccepted = trim _gidAccepted;

private _gidLastTask = ["lastTaskingGroup", ""] call ARC_fnc_stateGet;
if (!(_gidLastTask isEqualType "")) then { _gidLastTask = ""; };
_gidLastTask = trim _gidLastTask;

private _gid = _gidSitrep;
if (_gid isEqualTo "") then { _gid = _gidAccepted; };
if (_gid isEqualTo "") then { _gid = _gidLastTask; };

diag_log format ["[ARC][TOC] CloseIncident target group resolve: sitrep=%1 accepted=%2 lastTask=%3 -> chosen=%4 (caller=%5)", _gidSitrep, _gidAccepted, _gidLastTask, _gid, _callerName];

if (_taskId isEqualTo "" || { _gid isEqualTo "" }) exitWith
{
    diag_log format ["[ARC][TOC] CloseIncident aborted: missing context (gid=%1 taskId=%2) caller=%3", _gid, _taskId, _callerName];
    false
};

// Resolve an existing ISSUED order, or issue a default HOLD
private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) then { _orders = []; };

private _issuedId = "";
private _issuedType = "";
private _bestAt = -1;

{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
    if (!(_tg isEqualTo _gid)) then { continue; };
    if (!(toUpper _st isEqualTo "ISSUED")) then { continue; };
    if (!(_iat isEqualType 0)) then { _iat = -1; };
    if (_iat > _bestAt) then
    {
        _bestAt = _iat;
        _issuedId = _oid;
        _issuedType = _ot;
    };
} forEach _orders;

if (!(_issuedId isEqualType "")) then { _issuedId = ""; };
_issuedId = trim _issuedId;

if (_issuedId isEqualTo "") then
{
    // Default HOLD 15 min
    private _seed = [["holdIntent","Await further tasking."],["holdMinutes",15]];
    private _okIssue = ["HOLD", _gid, _seed, _caller, "", ""] call ARC_fnc_intelOrderIssue;
    if (!(_okIssue isEqualType true)) then { _okIssue = false; };
    if (!_okIssue) exitWith
    {
        diag_log format ["[ARC][TOC] CloseIncident failed: could not issue default HOLD order. gid=%1 caller=%2", _gid, _callerName];
        false
    };

    // Refresh list and resolve issued orderId
    _orders = ["tocOrders", []] call ARC_fnc_stateGet;
    if (!(_orders isEqualType [])) then { _orders = []; };

    _bestAt = -1;
    {
        if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
        _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
        if (!(_tg isEqualTo _gid)) then { continue; };
        if (!(toUpper _st isEqualTo "ISSUED")) then { continue; };
        if (!(_iat isEqualType 0)) then { _iat = -1; };
        if (_iat > _bestAt) then
        {
            _bestAt = _iat;
            _issuedId = _oid;
            _issuedType = _ot;
        };
    } forEach _orders;

    if (!(_issuedId isEqualType "")) then { _issuedId = ""; };
    _issuedId = trim _issuedId;

    if (_issuedId isEqualTo "") exitWith
    {
        diag_log format ["[ARC][TOC] CloseIncident failed: issued HOLD but could not resolve orderId. gid=%1 caller=%2", _gid, _callerName];
        false
    };
};

// Stage closeout pending acceptance
["activeIncidentClosePending", true] call ARC_fnc_stateSet;
["activeIncidentClosePendingAt", serverTime] call ARC_fnc_stateSet;
["activeIncidentClosePendingResult", _result] call ARC_fnc_stateSet;
["activeIncidentClosePendingOrderId", _issuedId] call ARC_fnc_stateSet;
["activeIncidentClosePendingGroup", _gid] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_activeIncidentClosePending", true, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", serverTime, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", _result, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", _issuedId, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", _gid, true];

// Publish orders snapshot so clients can accept the ISSUED order
[] call ARC_fnc_intelOrderBroadcast;


// Freeze execution while waiting
["activeIncidentCloseReady", true] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];

// Cleanup execution assets
["DEFER"] call ARC_fnc_execCleanupActive;

diag_log format ["[ARC][TOC] CloseIncident STAGED: by=%1 result=%2 gid=%3 task=%4 orderId=%5 orderType=%6", _callerName, _result, _gid, _taskId, _issuedId, _issuedType];

// Persist
[] call ARC_fnc_stateSave;

true
