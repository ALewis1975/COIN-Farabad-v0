/*
    ARC_fnc_tocRequestCloseoutAndOrder

    Server: process active incident closeout.

    Policy / decision matrix:
      - Immediate close path (policy gate ON):
          ARC_policy_noAutoOrdersOnCloseout = true
          -> close incident now via ARC_fnc_incidentClose
          -> queue follow-on package for TOC triage (no order acceptance gate)
      - Staged close path (policy gate OFF):
          ARC_policy_noAutoOrdersOnCloseout = false
          -> issue/reuse follow-on order for the SITREP group
          -> set activeIncidentClosePending* + activeIncidentCloseReady
          -> wait for acceptance before final close
      - Acceptance hook tie-in:
          functions/command/fn_intelOrderAccept.sqf checks activeIncidentClosePending
          and only calls ARC_fnc_incidentClose when acceptance matches
          activeIncidentClosePendingGroup + activeIncidentClosePendingOrderId
          (empty pending group/order are wildcard matches).

    Params (remoteExec from client):
      0: STRING closeResult       "SUCCEEDED" | "FAILED"
      1: STRING request           "RTB" | "HOLD" | "PROCEED"
      2: STRING purpose           (RTB) "REFIT" | "INTEL" | "EPW" | ""
      3: STRING rationale         optional (for logging)
      4: STRING constraints       optional (for logging)
      5: STRING support           optional (for logging)
      6: STRING notes             optional (order note)
      7: STRING holdIntent        optional
      8: NUMBER holdMinutes       optional
      9: STRING proceedIntent     optional

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_closeResult", "", [""]],
    ["_req", "", [""]],
    ["_purpose", "", [""]],
    ["_rationale", "", [""]],
    ["_constraints", "", [""]],
    ["_support", "", [""]],
    ["_notes", "", [""]],
    ["_holdIntent", "", [""]],
    ["_holdMinutes", -1, [0]],
    ["_proceedIntent", "", [""]],
    ["_callerParam", objNull, [objNull]]
];

// Identify the caller (prefer explicit caller param from UI)
private _caller = objNull;

if (!isNull _callerParam) then { _caller = _callerParam; };

// Fallback: remoteExecutedOwner mapping
if (isNull _caller && { !isNil "remoteExecutedOwner" }) then
{
    {
        if (owner _x == remoteExecutedOwner) exitWith { _caller = _x; };
    } forEach allPlayers;
};

if (isNull _caller) exitWith {false};

// RemoteExec-only validation path: requires remoteExecutedOwner context.
private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
if (!([_caller, "ARC_fnc_tocRequestCloseoutAndOrder", "Closeout rejected: sender verification failed.", "TOC_CLOSEOUT_SECURITY_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _owner = 0;
if (!isNull _caller) then { _owner = owner _caller; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

private _rpc = "ARC_fnc_tocRequestCloseoutAndOrder";
// Helper: send a toast back to the originating client (best-effort)
private _toast = {
    params ["_title", "_msg"];
    if (_owner > 0) then { [_title, _msg] remoteExec ["ARC_fnc_clientToast", _owner]; };
};

private _deny = {
    params ["_reason", ["_details", []], ["_toastMsg", ""]];

    private _who = if (isNull _caller) then {"<unknown>"} else {name _caller};
    private _uid = if (isNull _caller) then {""} else {getPlayerUID _caller};
    ["OPS", format ["SECURITY: %1 denied (%2) owner=%3 caller=%4", _rpc, _reason, _owner, _who], [0,0,0],
        [["event", "TOC_CLOSEOUT_SECURITY_DENIED"], ["rpc", _rpc], ["reason", _reason], ["remoteOwner", _owner], ["callerName", _who], ["callerUID", _uid]] + _details
    ] call ARC_fnc_intelLog;

    if (!(_toastMsg isEqualTo "")) then {
        ["TOC Ops", _toastMsg] call _toast;
    };
};

private _trimFn = compile "params ['_s']; trim _s";

// Authorization: reuse TOC/Command approval gate
if (!([_caller] call ARC_fnc_rolesCanApproveQueue)) exitWith
{
    ["ROLE_DENIED", [], "Closeout denied: you are not authorized to close incidents."] call _deny;
    false
};

_closeResult = toUpper (([_closeResult] call _trimFn));
if !(_closeResult in ["SUCCEEDED", "FAILED"]) exitWith {
    ["INVALID_PARAM_VALUE", [["param", "_closeResult"], ["received", _closeResult]], ""] call _deny;
    false
};

_req = toUpper (([_req] call _trimFn));
if !(_req in ["RTB","HOLD","PROCEED"]) then { _req = "HOLD"; };

_purpose = toUpper (([_purpose] call _trimFn));
if !(_purpose in ["REFIT","INTEL","EPW",""]) then { _purpose = "REFIT"; };

// -------------------------------------------------------------------------
// Shared closeout helpers
// -------------------------------------------------------------------------
private _clearPending = {
    params [["_reason", "INVALID", [""]]];

    ["activeIncidentClosePending", false] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingAt", -1] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingResult", ""] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingOrderId", ""] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingGroup", ""] call ARC_fnc_stateSet;

    missionNamespace setVariable ["ARC_activeIncidentClosePending", false, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", -1, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", "", true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", "", true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", "", true];

    diag_log format ["[ARC][TOC][WARN] CloseoutAndOrder preflight: cleared invalid activeIncidentClosePending* state. reason=%1", _reason];
};

private _findIssuedOrder = {
    params [
        ["_gidReq", "", [""]],
        ["_oidReq", "", [""]]
    ];

    private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
    if (!(_orders isEqualType [])) then { _orders = []; };

    private _bestId = "";
    private _bestType = "";
    private _bestAt = -1;

    {
        if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
        private _oid = _x select 0;
        private _iat = _x select 1;
        private _st = _x select 2;
        private _ot = _x select 3;
        private _tg = _x select 4;

        if (!(_oid isEqualType "")) then { _oid = ""; };
        if (!(_ot isEqualType "")) then { _ot = ""; };
        if (!(_tg isEqualType "")) then { _tg = ""; };
        if (!(_st isEqualType "")) then { _st = ""; };
        if (!(_iat isEqualType 0)) then { _iat = -1; };

        _oid = ([_oid] call _trimFn);
        _tg = ([_tg] call _trimFn);

        if (!(_gidReq isEqualTo "") && { !(_tg isEqualTo _gidReq) }) then { continue; };
        if (!(_oidReq isEqualTo "") && { !(_oid isEqualTo _oidReq) }) then { continue; };
        if (!(toUpper _st isEqualTo "ISSUED")) then { continue; };

        if (_iat > _bestAt) then
        {
            _bestAt = _iat;
            _bestId = _oid;
            _bestType = _ot;
        };
    } forEach _orders;

    [_bestId, _bestType, _bestAt]
};

private _stagePending = {
    params [
        ["_resultStage", "", [""]],
        ["_orderIdStage", "", [""]],
        ["_groupStage", "", [""]]
    ];

    if (_orderIdStage isEqualTo "" || { _groupStage isEqualTo "" }) exitWith { false };

    private _stageAt = serverTime;

    ["activeIncidentClosePending", true] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingAt", _stageAt] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingResult", _resultStage] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingOrderId", _orderIdStage] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingGroup", _groupStage] call ARC_fnc_stateSet;

    ["activeIncidentCloseReady", true] call ARC_fnc_stateSet;

    missionNamespace setVariable ["ARC_activeIncidentClosePending", true, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", _stageAt, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", _resultStage, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", _orderIdStage, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", _groupStage, true];
    missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];

    // Publish orders snapshot so clients can see/accept the pending ISSUED order.
    [] call ARC_fnc_intelOrderBroadcast;

    true
};

private _approveEodIfNeeded = {
    params [
        ["_incidentType", "", [""]],
        ["_taskIdRef", "", [""]],
        ["_gidRef", "", [""]],
        ["_posRef", [0,0,0], [[]]]
    ];

    if !(toUpper (([_incidentType] call _trimFn)) isEqualTo "IED") exitWith { false };

    private _eodReqU = toUpper (([["activeIncidentEodDispoRequestedType", ""] call ARC_fnc_stateGet] call _trimFn));
    private _objKindU = toUpper (([["activeIncidentEodDispoObjectiveKind", ""] call ARC_fnc_stateGet] call _trimFn));

    if (!(_eodReqU in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"]) || { !(_objKindU in ["IED_DEVICE","VBIED_VEHICLE"]) }) exitWith { false };

    private _ttl = missionNamespace getVariable ["ARC_eodDispoApprovalTTLsec", 900];
    if (!(_ttl isEqualType 0)) then { _ttl = 900; };
    _ttl = (_ttl max 60) min (60*60);

    private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
    if (!(_appr isEqualType [])) then { _appr = []; };

    private _exp = serverTime + _ttl;
    private _notesE = ([["activeIncidentEodDispoNotes", ""] call ARC_fnc_stateGet] call _trimFn);

    // Remove any existing approval for this task+group+type before adding a new one (prevents duplicates)
    _appr = _appr select {
        !(_x isEqualType [] && { (count _x) >= 6 } && { (_x select 0) isEqualTo _taskIdRef } && { (_x select 1) isEqualTo _gidRef } && { (toUpper (([_x select 2] call _trimFn))) isEqualTo _eodReqU })
    };
    _appr pushBack [_taskIdRef, _gidRef, _eodReqU, serverTime, if (isNull _caller) then {"TOC"} else { name _caller }, _exp, _notesE];

    // Cap to avoid unbounded growth
    private _cap = 50;
    if ((count _appr) > _cap) then { _appr = _appr select [((count _appr) - _cap) max 0, _cap]; };
    ["eodDispoApprovals", _appr] call ARC_fnc_stateSet;

    // Broadcast for clients
    [] call ARC_fnc_iedDispoBroadcast;

    ["OPS", format ["TOC approved EOD disposition as part of closeout: %1 (%2).", _eodReqU, _gidRef], _posRef,
        [["event","TOC_EOD_APPROVED"],["taskId",_taskIdRef],["targetGroup",_gidRef],["requestType",_eodReqU],["objectiveKind",_objKindU]]
    ] call ARC_fnc_intelLog;

    true
};

// Active context (rehydrate before pending validation so stale-state checks can
// distinguish an actually live pending closeout from orphaned persistence).
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_taskId isEqualType "")) then { _taskId = ""; };
_taskId = ([_taskId] call _trimFn);

if (_taskId isEqualTo "") then
{
    [] call ARC_fnc_taskRehydrateActive;
    _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (!(_taskId isEqualType "")) then { _taskId = ""; };
    _taskId = ([_taskId] call _trimFn);
};

// Pending closeout preflight: do not blindly clear valid pending orders. A valid
// pending record means the unit still needs to accept the issued follow-on.
private _pending = ["activeIncidentClosePending", false] call ARC_fnc_stateGet;
if (!(_pending isEqualType true)) then { _pending = false; };

private _denyAlreadyPending = false;
if (_pending) then
{
    private _pendingOrderId = ["activeIncidentClosePendingOrderId", ""] call ARC_fnc_stateGet;
    if (!(_pendingOrderId isEqualType "")) then { _pendingOrderId = ""; };
    _pendingOrderId = ([_pendingOrderId] call _trimFn);

    private _pendingGroup = ["activeIncidentClosePendingGroup", ""] call ARC_fnc_stateGet;
    if (!(_pendingGroup isEqualType "")) then { _pendingGroup = ""; };
    _pendingGroup = ([_pendingGroup] call _trimFn);

    private _foundPending = ["", "", -1];
    if (!(_taskId isEqualTo "") && { !(_pendingOrderId isEqualTo "") } && { !(_pendingGroup isEqualTo "") }) then
    {
        _foundPending = [_pendingGroup, _pendingOrderId] call _findIssuedOrder;
    };

    private _foundPendingId = _foundPending select 0;
    private _foundPendingType = _foundPending select 1;

    if (!(_foundPendingId isEqualTo "")) then
    {
        diag_log format ["[ARC][TOC] CloseoutAndOrder denied: already pending. task=%1 gid=%2 orderId=%3 orderType=%4 caller=%5", _taskId, _pendingGroup, _foundPendingId, _foundPendingType, if (isNull _caller) then {"<unknown>"} else { name _caller }];
        ["TOC Ops", format ["Closeout already pending: awaiting %1 acceptance of order %2.", _pendingGroup, _foundPendingId]] call _toast;
        _denyAlreadyPending = true;
    }
    else
    {
        [format ["task=%1 pendingGroup=%2 pendingOrderId=%3 orderStillIssued=false", _taskId, _pendingGroup, _pendingOrderId]] call _clearPending;
    };
};
if (_denyAlreadyPending) exitWith { false };

// Require SITREP for the active incident
private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };
if (!_sitrepSent) exitWith
{
    ["MISSING_SITREP", [], "Closeout denied: SITREP not received yet for the active incident."] call _deny;
    false
};

// Group context. Prefer the SITREP group normally, but if it disagrees with the
// accepted task owner, route follow-ons to the accepted owner so the executing
// unit can accept the resulting order from its console.
private _gidSitrep = ["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateGet;
if (!(_gidSitrep isEqualType "")) then { _gidSitrep = ""; };
_gidSitrep = ([_gidSitrep] call _trimFn);

private _gidAccepted = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (!(_gidAccepted isEqualType "")) then { _gidAccepted = ""; };
_gidAccepted = ([_gidAccepted] call _trimFn);

private _gidLast = ["lastSitrepFromGroup", ""] call ARC_fnc_stateGet;
if (!(_gidLast isEqualType "")) then { _gidLast = ""; };
_gidLast = ([_gidLast] call _trimFn);

private _gid = _gidSitrep;
if (!(_gidSitrep isEqualTo "") && { !(_gidAccepted isEqualTo "") } && { !(_gidSitrep isEqualTo _gidAccepted) }) then
{
    diag_log format ["[ARC][TOC][WARN] CloseoutAndOrder group mismatch: sitrep=%1 accepted=%2 last=%3 -> using accepted group", _gidSitrep, _gidAccepted, _gidLast];
    _gid = _gidAccepted;
};
if (_gid isEqualTo "") then { _gid = _gidAccepted; };
if (_gid isEqualTo "") then { _gid = _gidLast; };

// Diagnostic: catch group mismatch / target resolution.
diag_log format ["[ARC][TOC] Closeout target group resolve: sitrep=%1 accepted=%2 last=%3 -> chosen=%4", _gidSitrep, _gidAccepted, _gidLast, _gid];

if (_gid isEqualTo "" || { _taskId isEqualTo "" }) exitWith
{
    ["MISSING_CONTEXT", [["gid", _gid], ["taskId", _taskId]], "Closeout failed: server is missing active incident context. (Try: Rebuild Active Incident Task)."] call _deny;
    diag_log format ["[ARC][TOC] tocRequestCloseoutAndOrder aborted: missing context (gid=%1 taskId=%2).", _gid, _taskId];
    false
};

// -------------------------------------------------------------------------
// Closeout branch policy gate:
//   ARC_policy_noAutoOrdersOnCloseout = true  -> IMMEDIATE close + TOC follow-on package.
//   ARC_policy_noAutoOrdersOnCloseout = false -> STAGED close (order acceptance trigger).
// -------------------------------------------------------------------------
private _noAutoOrders = missionNamespace getVariable ["ARC_policy_noAutoOrdersOnCloseout", false];
if (!(_noAutoOrders isEqualType true)) then { _noAutoOrders = true; };

if (_noAutoOrders) exitWith
{
    // Capture incident context BEFORE closing (incidentClose clears many keys)
    private _itype = ["activeIncidentType", ""] call ARC_fnc_stateGet;
    if (!(_itype isEqualType "")) then { _itype = ""; };
    _itype = ([_itype] call _trimFn);

    private _imarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
    if (!(_imarker isEqualType "")) then { _imarker = ""; };
    _imarker = ([_imarker] call _trimFn);

    private _izone = ["activeIncidentZone", ""] call ARC_fnc_stateGet;
    if (!(_izone isEqualType "")) then { _izone = ""; };
    _izone = ([_izone] call _trimFn);

    private _idisplay = ["activeIncidentDisplayName", "Incident"] call ARC_fnc_stateGet;
    if (!(_idisplay isEqualType "")) then { _idisplay = "Incident"; };
    _idisplay = ([_idisplay] call _trimFn);
    if (_idisplay isEqualTo "") then { _idisplay = "Incident"; };

    private _iposATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    if (!(_iposATL isEqualType []) || { (count _iposATL) < 2 }) then { _iposATL = [0,0,0]; };
    _iposATL resize 3;

    private _sitSum = ["activeIncidentSitrepSummary", ""] call ARC_fnc_stateGet;
    if (!(_sitSum isEqualType "")) then { _sitSum = ""; };

    private _sitDet = ["activeIncidentSitrepDetails", ""] call ARC_fnc_stateGet;
    if (!(_sitDet isEqualType "")) then { _sitDet = ""; };

    // Defensive: force-fail IED closeout if CIV KIA occurred
    if (_closeResult isEqualTo "SUCCEEDED" && { toUpper _itype isEqualTo "IED" }) then
    {
        private _civKia = ["activeIedCivKia", 0] call ARC_fnc_stateGet;
        if (!(_civKia isEqualType 0)) then { _civKia = 0; };
        if (_civKia > 0) then { _closeResult = "FAILED"; };
    };

    [_itype, _taskId, _gid, _iposATL] call _approveEodIfNeeded;

    // IMMEDIATE branch: close now and publish queue package (no order acceptance gate).
    private _resFinal = _closeResult;
    diag_log format ["[ARC][TOC][CLOSEOUT][BRANCH=IMMEDIATE] trigger=request by=%1 result=%2 gid=%3 task=%4", if (isNull _caller) then {"<unknown>"} else {name _caller}, _resFinal, _gid, _taskId];
    [_resFinal] call ARC_fnc_incidentClose;

    // Collect any leads tied to this incident/task for TOC triage.
    private _leadIds = [];
    private _pool = ["leadPool", []] call ARC_fnc_stateGet;
    if (!(_pool isEqualType [])) then { _pool = []; };

    {
        if (_x isEqualType [] && { (count _x) >= 8 }) then
        {
            private _lid = _x select 0;
            private _srcTask = _x select 7;
            if (_lid isEqualType "" && { _srcTask isEqualType "" } && { _srcTask isEqualTo _taskId }) then
            {
                _leadIds pushBackUnique _lid;
            };
        };
    } forEach _pool;

    // Publish a follow-on package into the TOC Queue for visibility and explicit assignment.
    if ((count _leadIds) > 0) then
    {
        private _payload = [
            ["sourceTaskId", _taskId],
            ["sourceIncidentType", _itype],
            ["result", _resFinal],
            ["recommendation", _req],
            ["purpose", _purpose],
            ["leadIds", _leadIds],
            ["sitrepSummary", _sitSum]
        ];

        private _summary = format ["Follow-on Package: %1 (%2) [%3 lead(s)]", _idisplay, _resFinal, (count _leadIds)];
        private _details = _sitDet;

        [objNull, "FOLLOWON_PACKAGE", _payload, _summary, _details, _iposATL, [["closedBy", if (isNull _caller) then {"SYSTEM"} else { name _caller }], ["targetGroup", _gid]]] call ARC_fnc_intelQueueSubmit;
    };

    private _whoDone = if (isNull _caller) then {"<unknown>"} else { name _caller };
    diag_log format ["[ARC][TOC][CLOSEOUT][BRANCH=IMMEDIATE] complete by=%1 result=%2 gid=%3 task=%4 leads=%5", _whoDone, _resFinal, _gid, _taskId, (count _leadIds)];
    ["OPS", format ["Closeout immediate by %1: %2. Follow-on package queued with %3 lead(s).", _whoDone, _resFinal, (count _leadIds)], _iposATL,
        [["event","CLOSEOUT_IMMEDIATE"],["path","IMMEDIATE_TOC_QUEUE"],["taskId",_taskId],["result",_resFinal],["targetGroup",_gid],["leadCount",(count _leadIds)]]
    ] call ARC_fnc_intelLog;

    ["TOC Ops", format ["Closed immediately: %1 (%2). Follow-on package queued (%3 lead(s)).", _idisplay, _resFinal, (count _leadIds)]] call _toast;
    true
};

// Guard: prevent stacking multiple ISSUED orders for the same group. If one is
// already issued, reuse it and arm the pending closeout once.
private _issued = [_gid, ""] call _findIssuedOrder;
private _issuedId = _issued select 0;
private _issuedType = _issued select 1;

if (!(_issuedId isEqualTo "")) exitWith
{
    private _stageOk = [_closeResult, _issuedId, _gid] call _stagePending;
    if (!_stageOk) exitWith
    {
        ["TOC Ops", "Closeout denied: ISSUED order exists but pending state could not be staged."] call _toast;
        false
    };

    // Freeze execution while waiting
    ["DEFER"] call ARC_fnc_execCleanupActive;

    private _whoDone = if (isNull _caller) then {"<unknown>"} else { name _caller };
    diag_log format ["[ARC][TOC][CLOSEOUT][BRANCH=STAGED_REUSED_ORDER] armed by=%1 result=%2 gid=%3 task=%4 orderId=%5 orderType=%6", _whoDone, _closeResult, _gid, _taskId, _issuedId, _issuedType];

    private _sposATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    if (!(_sposATL isEqualType []) || { (count _sposATL) < 2 }) then { _sposATL = [0,0,0]; };
    _sposATL resize 3;

    ["OPS", format ["Closeout staged by %1: %2. Reusing ISSUED order %3 (%4) for %5 acceptance.", _whoDone, _closeResult, _issuedId, _issuedType, _gid], _sposATL,
        [["event","CLOSEOUT_STAGED"],["path","STAGED_REUSED_ORDER"],["taskId",_taskId],["result",_closeResult],["orderType",_issuedType],["orderId",_issuedId],["targetGroup",_gid]]
    ] call ARC_fnc_intelLog;

    ["TOC Ops", format ["Closeout staged: %1. Reusing existing ISSUED order (%2). Awaiting unit acceptance.", _closeResult, _issuedType]] call _toast;

    [] call ARC_fnc_stateSave;

    true
};

// Incident context for lead generation / logging
private _type = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_type isEqualType "")) then { _type = ""; };
_type = ([_type] call _trimFn);

private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
if (!(_marker isEqualType "")) then { _marker = ""; };
_marker = ([_marker] call _trimFn);

private _posATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) then { _posATL = []; };

private _display = ["activeIncidentDisplayName", "Incident"] call ARC_fnc_stateGet;
if (!(_display isEqualType "")) then { _display = "Incident"; };

private _pos = [];
if (!(_posATL isEqualTo [])) then { _pos = +_posATL; _pos resize 3; };
if (_pos isEqualTo []) then { _pos = [0,0,0]; };

private _zone = if (_marker isEqualTo "") then { [_pos] call ARC_fnc_worldGetZoneForPos } else { [_marker] call ARC_fnc_worldGetZoneForMarker };

// Enforce IED detonation rule: any CIV KIA forces FAIL.
if (_closeResult isEqualTo "SUCCEEDED" && { toUpper _type isEqualTo "IED" }) then
{
    private _civKia = ["activeIedCivKia", 0] call ARC_fnc_stateGet;
    if (!(_civKia isEqualType 0)) then { _civKia = 0; };
    if (_civKia > 0) then
    {
        _closeResult = "FAILED";
        [
            "OPS",
            format ["Closeout overridden: requested SUCCEEDED but CIV KIA=%1. Forced FAILED.", _civKia],
            _pos,
            [["taskId", _taskId], ["event", "CLOSEOUT_FORCED_FAIL"], ["civKia", _civKia]]
        ] call ARC_fnc_intelLog;
    };
};

// Capture system-suggested follow-on lead (if any)
private _foLeadIdCaptured = ["activeIncidentFollowOnLeadId", ""] call ARC_fnc_stateGet;
if (!(_foLeadIdCaptured isEqualType "")) then { _foLeadIdCaptured = ""; };
_foLeadIdCaptured = ([_foLeadIdCaptured] call _trimFn);

// Snapshot lead pool before generating
private _leadIdsBefore = [];
private _leadsBefore = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leadsBefore isEqualType [])) then { _leadsBefore = []; };
{
    if (_x isEqualType [] && { (count _x) >= 1 }) then
    {
        private _lid = _x select 0;
        if (_lid isEqualType "" && { !(_lid isEqualTo "") }) then { _leadIdsBefore pushBackUnique _lid; };
    };
} forEach _leadsBefore;

// STAGED branch support: generate follow-on leads now so a PROCEED/LEAD order can reference one.
private _createdLeads = [_closeResult, _type, _marker, _pos, _zone, _taskId, _display] call ARC_fnc_leadGenerateFromIncident;
if (!(_createdLeads isEqualType 0)) then { _createdLeads = 0; };

["activeIncidentClosePendingLeadsGenerated", true] call ARC_fnc_stateSet;
["activeIncidentClosePendingLeadsCreated", _createdLeads] call ARC_fnc_stateSet;

// Detect newly created leads linked to this closeout (sourceTaskId == _taskId)
private _genLeadId = "";
private _genLeadName = "";
private _genLeadType = "";
private _leadsAfter = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leadsAfter isEqualType [])) then { _leadsAfter = []; };

{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    private _lid = _x select 0;
    private _srcTask = _x select 6;
    if (!(_lid isEqualType "")) then { continue; };
    if (!(_srcTask isEqualType "")) then { continue; };

    if (!(_lid in _leadIdsBefore) && { _srcTask isEqualTo _taskId }) then
    {
        _genLeadId = _lid;
        _genLeadType = _x select 1;
        _genLeadName = _x select 2;
    };
} forEach _leadsAfter;

if (!(_genLeadId isEqualTo "")) then
{
    ["lastCloseoutGeneratedLeadId", _genLeadId] call ARC_fnc_stateSet;
    ["lastCloseoutGeneratedLeadName", _genLeadName] call ARC_fnc_stateSet;
    ["lastCloseoutGeneratedLeadType", _genLeadType] call ARC_fnc_stateSet;

    missionNamespace setVariable ["ARC_lastCloseoutGeneratedLeadId", _genLeadId, true];
    missionNamespace setVariable ["ARC_lastCloseoutGeneratedLeadName", _genLeadName, true];
    missionNamespace setVariable ["ARC_lastCloseoutGeneratedLeadType", _genLeadType, true];
};

// Build follow-on order
private _orderType = _req;
if (_req isEqualTo "PROCEED") then { _orderType = "LEAD"; };

[_type, _taskId, _gid, _pos] call _approveEodIfNeeded;

private _seed = [];
if (!(([_rationale] call _trimFn) isEqualTo "")) then { _seed pushBack ["rationale", ([_rationale] call _trimFn)]; };
if (!(([_constraints] call _trimFn) isEqualTo "")) then { _seed pushBack ["constraints", ([_constraints] call _trimFn)]; };
if (!(([_support] call _trimFn) isEqualTo "")) then { _seed pushBack ["support", ([_support] call _trimFn)]; };

if (_orderType isEqualTo "RTB") then { _seed pushBack ["purpose", _purpose]; };

if (_orderType isEqualTo "HOLD") then
{
    if (!(([_holdIntent] call _trimFn) isEqualTo "")) then { _seed pushBack ["holdIntent", ([_holdIntent] call _trimFn)]; };
    if (_holdMinutes isEqualType 0 && { _holdMinutes > 0 }) then { _seed pushBack ["holdMinutes", _holdMinutes]; };
};

if (_orderType isEqualTo "LEAD") then
{
    if (!(([_proceedIntent] call _trimFn) isEqualTo "")) then { _seed pushBack ["proceedIntent", ([_proceedIntent] call _trimFn)]; };

    // Prefer system-suggested follow-on lead, otherwise the closeout-generated lead.
    if (!(_foLeadIdCaptured isEqualTo "")) then
    {
        _seed pushBack ["leadId", _foLeadIdCaptured];
    }
    else
    {
        if (!(_genLeadId isEqualTo "")) then { _seed pushBack ["leadId", _genLeadId]; };
    };
};

private _orderNote = ([_notes] call _trimFn);

private _issueOk = [_orderType, _gid, _seed, _caller, _orderNote, ""] call ARC_fnc_intelOrderIssue;
if (!(_issueOk isEqualType true)) then { _issueOk = false; };

if (!_issueOk) exitWith
{
    diag_log format ["[ARC][TOC] CloseoutAndOrder FAILED: order issuance failed (type=%1 gid=%2).", _orderType, _gid];
    ["TOC Ops", "Closeout failed: could not issue follow-on order (see server RPT)."] call _toast;
    false
};

// Resolve newly issued orderId (latest ISSUED to this group)
private _newIssued = [_gid, ""] call _findIssuedOrder;
private _orderId = _newIssued select 0;

if (_orderId isEqualTo "") exitWith
{
    diag_log format ["[ARC][TOC] CloseoutAndOrder FAILED: issued order but could not resolve ISSUED orderId (type=%1 gid=%2).", _orderType, _gid];
    ["TOC Ops", "Closeout failed: issued follow-on order but could not resolve order ID."] call _toast;
    false
};

private _stageOk = [_closeResult, _orderId, _gid] call _stagePending;
if (!_stageOk) exitWith
{
    diag_log format ["[ARC][TOC] CloseoutAndOrder FAILED: could not stage pending closeout (orderId=%1 gid=%2).", _orderId, _gid];
    ["TOC Ops", "Closeout failed: could not stage pending closeout."] call _toast;
    false
};

// End active execution package objects (deferred cleanup)
["DEFER"] call ARC_fnc_execCleanupActive;

private _whoDone = if (isNull _caller) then {"<unknown>"} else { name _caller };
diag_log format ["[ARC][TOC][CLOSEOUT][BRANCH=STAGED_NEW_ORDER] armed by=%1 result=%2 orderType=%3 gid=%4 task=%5 orderId=%6", _whoDone, _closeResult, _orderType, _gid, _taskId, _orderId];

private _orderLine = if (_orderType isEqualTo "RTB") then { format ["RTB (%1)", _purpose] } else { if (_orderType isEqualTo "LEAD") then { "PROCEED" } else { _orderType } };
["TOC Ops", format ["Closeout staged: %1. Order issued: %2. Awaiting unit acceptance.", _closeResult, _orderLine]] call _toast;

["OPS", format ["Closeout staged by %1: %2. Awaiting %3 acceptance of order %4 (%5).", _whoDone, _closeResult, _gid, _orderId, _orderLine], _pos,
    [["event","CLOSEOUT_STAGED"],["path","STAGED_NEW_ORDER"],["taskId",_taskId],["result",_closeResult],["orderType",_orderType],["orderId",_orderId],["targetGroup",_gid]]
] call ARC_fnc_intelLog;

[] call ARC_fnc_stateSave;
true
