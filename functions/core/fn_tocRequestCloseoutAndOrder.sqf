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
if (!([_caller, "ARC_fnc_tocRequestCloseoutAndOrder", "Closeout rejected: sender verification failed.", "TOC_CLOSEOUT_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _owner = 0;
if (!isNull _caller) then { _owner = owner _caller; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

private _rpc = "ARC_fnc_tocRequestCloseoutAndOrder";
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

// Helper: send a toast back to the originating client (best-effort)
private _toast = {
    params ["_title", "_msg"];
    if (_owner > 0) then { [_title, _msg] remoteExec ["ARC_fnc_clientToast", _owner]; };
};

// Authorization: reuse TOC/Command approval gate
if (!([_caller] call ARC_fnc_rolesCanApproveQueue)) exitWith
{
    ["ROLE_DENIED", [], "Closeout denied: you are not authorized to close incidents."] call _deny;
    false
};

_closeResult = toUpper (trim _closeResult);
if !(_closeResult in ["SUCCEEDED", "FAILED"]) exitWith {
    ["INVALID_PARAM_VALUE", [["param", "_closeResult"], ["received", _closeResult]], ""] call _deny;
    false
};

_req = toUpper (trim _req);
if !(_req in ["RTB","HOLD","PROCEED"]) then { _req = "HOLD"; };

_purpose = toUpper (trim _purpose);
if !(_purpose in ["REFIT","INTEL","EPW",""]) then { _purpose = "REFIT"; };

// Defensive reset: clear stale staged-close flags left over from a previous flow
// before evaluating whether this request will run immediate-close or staged-close.
private _pending = ["activeIncidentClosePending", false] call ARC_fnc_stateGet;
if (!(_pending isEqualType true)) then { _pending = false; };
if (_pending) then
{
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

    diag_log "[ARC][TOC] Closeout path preflight: cleared stale activeIncidentClosePending* state.";
};

// Require SITREP for the active incident
private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };
if (!_sitrepSent) exitWith
{
    ["MISSING_SITREP", [], "Closeout denied: SITREP not received yet for the active incident."] call _deny;
    false
};

// Active context (rehydrate if needed)
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

// Group context (Farabad rule): follow-on orders go to the unit that SENT the SITREP.
// Fallbacks exist for edge cases where SITREP data is missing.
private _gidSitrep = ["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateGet;
if (!(_gidSitrep isEqualType "")) then { _gidSitrep = ""; };
_gidSitrep = trim _gidSitrep;

private _gidAccepted = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (!(_gidAccepted isEqualType "")) then { _gidAccepted = ""; };
_gidAccepted = trim _gidAccepted;

private _gidLast = ["lastSitrepFromGroup", ""] call ARC_fnc_stateGet;
if (!(_gidLast isEqualType "")) then { _gidLast = ""; };
_gidLast = trim _gidLast;

private _gid = _gidSitrep;
if (_gid isEqualTo "") then { _gid = _gidAccepted; };
if (_gid isEqualTo "") then { _gid = _gidLast; };

// Diagnostic: catch group mismatch (order issued to wrong unit)
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
private _noAutoOrders = missionNamespace getVariable ["ARC_policy_noAutoOrdersOnCloseout", true];
if (!(_noAutoOrders isEqualType true)) then { _noAutoOrders = true; };

if (_noAutoOrders) exitWith
{
    // Capture incident context BEFORE closing (incidentClose clears many keys)
    private _itype = ["activeIncidentType", ""] call ARC_fnc_stateGet;
    if (!(_itype isEqualType "")) then { _itype = ""; };
    _itype = trim _itype;

    private _imarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
    if (!(_imarker isEqualType "")) then { _imarker = ""; };
    _imarker = trim _imarker;

    private _izone = ["activeIncidentZone", ""] call ARC_fnc_stateGet;
    if (!(_izone isEqualType "")) then { _izone = ""; };
    _izone = trim _izone;

    private _idisplay = ["activeIncidentDisplayName", "Incident"] call ARC_fnc_stateGet;
    if (!(_idisplay isEqualType "")) then { _idisplay = "Incident"; };
    _idisplay = trim _idisplay;
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

    // Preserve the convenience behavior: IED/VBIED closeout can approve EOD disposition.
    if (toUpper (trim _itype) isEqualTo "IED") then
    {
        private _eodReqU = toUpper (trim (["activeIncidentEodDispoRequestedType", ""] call ARC_fnc_stateGet));
        private _objKindU = toUpper (trim (["activeIncidentEodDispoObjectiveKind", ""] call ARC_fnc_stateGet));

        if (_eodReqU in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"] && { _objKindU in ["IED_DEVICE","VBIED_VEHICLE"] }) then
        {
            private _ttl = missionNamespace getVariable ["ARC_eodDispoApprovalTTLsec", 900];
            if (!(_ttl isEqualType 0)) then { _ttl = 900; };
            _ttl = (_ttl max 60) min (60*60);

            private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
            if (!(_appr isEqualType [])) then { _appr = []; };

            private _exp = serverTime + _ttl;
            private _notesE = trim (["activeIncidentEodDispoNotes", ""] call ARC_fnc_stateGet);

            // Remove any existing approval for this task+group+type before adding a new one (prevents duplicates)
            _appr = _appr select {
                !(_x isEqualType [] && { (count _x) >= 6 } && { (_x select 0) isEqualTo _taskId } && { (_x select 1) isEqualTo _gid } && { (toUpper (trim (_x select 2))) isEqualTo _eodReqU })
            };
            _appr pushBack [_taskId, _gid, _eodReqU, serverTime, if (isNull _caller) then {"TOC"} else { name _caller }, _exp, _notesE];

            // Cap to avoid unbounded growth
            private _cap = 50;
            if ((count _appr) > _cap) then { _appr = _appr select [((count _appr) - _cap) max 0, _cap]; };
            ["eodDispoApprovals", _appr] call ARC_fnc_stateSet;

            // Broadcast for clients
            [] call ARC_fnc_iedDispoBroadcast;

            ["OPS", format ["TOC approved EOD disposition as part of closeout: %1 (%2).", _eodReqU, _gid], _iposATL,
                [["event","TOC_EOD_APPROVED"],["taskId",_taskId],["targetGroup",_gid],["requestType",_eodReqU],["objectiveKind",_objKindU]]
            ] call ARC_fnc_intelLog;
        };
    };

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

// Guard: prevent stacking multiple ISSUED orders for the same group
private _ordersExisting = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_ordersExisting isEqualType [])) then { _ordersExisting = []; };

private _hasIssued = false;
{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
    if (!(_tg isEqualTo _gid)) then { continue; };
    if (toUpper _st isEqualTo "ISSUED") exitWith { _hasIssued = true; };
} forEach _ordersExisting;

if (_hasIssued) exitWith
{
    // Reuse the existing ISSUED order instead of hard-failing.
    private _reuseId = "";
    private _reuseType = "";
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
            _reuseId = _oid;
            _reuseType = _ot;
        };
    } forEach _ordersExisting;

    if (!(_reuseId isEqualType "")) then { _reuseId = ""; };
    _reuseId = trim _reuseId;

    if (_reuseId isEqualTo "") exitWith
    {
        ["TOC Ops", "Closeout denied: ISSUED order exists but could not resolve orderId."] call _toast;
        false
    };

    // STAGED branch (reused ISSUED order): wait for acceptance trigger in fn_intelOrderAccept.
    ["activeIncidentClosePending", true] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingAt", serverTime] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingResult", _closeResult] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingOrderId", _reuseId] call ARC_fnc_stateSet;
    ["activeIncidentClosePendingGroup", _gid] call ARC_fnc_stateSet;

    missionNamespace setVariable ["ARC_activeIncidentClosePending", true, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", serverTime, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", _closeResult, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", _reuseId, true];
    missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", _gid, true];
    // Publish orders snapshot so clients can see/accept the reused ISSUED order
    [] call ARC_fnc_intelOrderBroadcast;


    ["activeIncidentCloseReady", true] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];

    ["DEFER"] call ARC_fnc_execCleanupActive;

    private _whoDone = if (isNull _caller) then {"<unknown>"} else { name _caller };
    diag_log format ["[ARC][TOC][CLOSEOUT][BRANCH=STAGED_REUSED_ORDER] armed by=%1 result=%2 gid=%3 task=%4 orderId=%5 orderType=%6", _whoDone, _closeResult, _gid, _taskId, _reuseId, _reuseType];
    ["OPS", format ["Closeout staged by %1: %2. Reusing ISSUED order %3 (%4) for %5 acceptance.", _whoDone, _closeResult, _reuseId, _reuseType, _gid], _posATL,
        [["event","CLOSEOUT_STAGED"],["path","STAGED_REUSED_ORDER"],["taskId",_taskId],["result",_closeResult],["orderType",_reuseType],["orderId",_reuseId],["targetGroup",_gid]]
    ] call ARC_fnc_intelLog;

    ["TOC Ops", format ["Closeout staged: %1. Reusing existing ISSUED order (%2). Awaiting unit acceptance.", _closeResult, _reuseType]] call _toast;

    [] call ARC_fnc_stateSave;

    true
};

// Incident context for lead generation / logging
private _type = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_type isEqualType "")) then { _type = ""; };
_type = trim _type;

private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
if (!(_marker isEqualType "")) then { _marker = ""; };
_marker = trim _marker;

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
_foLeadIdCaptured = trim _foLeadIdCaptured;

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

// IED/VBIED closeout: if the SITREP included an EOD disposition request, treat this closeout
// action as TOC approval and broadcast it immediately (no separate UI hunt).
private _incTypeU = toUpper (trim (['activeIncidentType',''] call ARC_fnc_stateGet));
if (_incTypeU isEqualTo "IED") then
{
    private _eodReqU = toUpper (trim (['activeIncidentEodDispoRequestedType',''] call ARC_fnc_stateGet));
    private _objKindU = toUpper (trim (['activeIncidentEodDispoObjectiveKind',''] call ARC_fnc_stateGet));
    if (_eodReqU in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"] && { _objKindU in ["IED_DEVICE","VBIED_VEHICLE"] }) then
    {
        private _ttl = missionNamespace getVariable ["ARC_eodDispoApprovalTTLsec", 900];
        if (!(_ttl isEqualType 0)) then { _ttl = 900; };
        _ttl = (_ttl max 60) min (60*60);

        private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
        if (!(_appr isEqualType [])) then { _appr = []; };

        private _exp = serverTime + _ttl;
        private _notesE = trim (['activeIncidentEodDispoNotes',''] call ARC_fnc_stateGet);

        // Remove any existing approval for this task+group+type before adding a new one (prevents duplicates)
        _appr = _appr select {
            !(_x isEqualType [] && { (count _x) >= 6 } && { (_x select 0) isEqualTo _taskId } && { (_x select 1) isEqualTo _gid } && { (toUpper (trim (_x select 2))) isEqualTo _eodReqU })
        };
        _appr pushBack [_taskId, _gid, _eodReqU, serverTime, if (isNull _caller) then {"TOC"} else { name _caller }, _exp, _notesE];

        // Cap to avoid unbounded growth
        private _cap = 50;
        if ((count _appr) > _cap) then { _appr = _appr select [((count _appr) - _cap) max 0, _cap]; };
        ["eodDispoApprovals", _appr] call ARC_fnc_stateSet;

        // Broadcast for clients
        [] call ARC_fnc_iedDispoBroadcast;

        ["OPS", format ["TOC approved EOD disposition as part of closeout: %1 (%2).", _eodReqU, _gid], _pos,
            [["event","TOC_EOD_APPROVED"],["taskId",_taskId],["targetGroup",_gid],["requestType",_eodReqU],["objectiveKind",_objKindU]]
        ] call ARC_fnc_intelLog;
    };
};

private _seed = [];
if (trim !(_rationale isEqualTo "")) then { _seed pushBack ["rationale", trim _rationale]; };
if (trim !(_constraints isEqualTo "")) then { _seed pushBack ["constraints", trim _constraints]; };
if (trim !(_support isEqualTo "")) then { _seed pushBack ["support", trim _support]; };

if (_orderType isEqualTo "RTB") then { _seed pushBack ["purpose", _purpose]; };

if (_orderType isEqualTo "HOLD") then
{
    if (trim !(_holdIntent isEqualTo "")) then { _seed pushBack ["holdIntent", trim _holdIntent]; };
    if (_holdMinutes isEqualType 0 && { _holdMinutes > 0 }) then { _seed pushBack ["holdMinutes", _holdMinutes]; };
};

if (_orderType isEqualTo "LEAD") then
{
    if (trim !(_proceedIntent isEqualTo "")) then { _seed pushBack ["proceedIntent", trim _proceedIntent]; };

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

private _orderNote = trim _notes;

private _issueOk = [_orderType, _gid, _seed, _caller, _orderNote, ""] call ARC_fnc_intelOrderIssue;
if (!(_issueOk isEqualType true)) then { _issueOk = false; };

if (!_issueOk) exitWith
{
    diag_log format ["[ARC][TOC] CloseoutAndOrder FAILED: order issuance failed (type=%1 gid=%2).", _orderType, _gid];
    ["TOC Ops", "Closeout failed: could not issue follow-on order (see server RPT)."] call _toast;
    false
};

// Resolve newly issued orderId (latest ISSUED to this group)
private _orderId = "";
private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) then { _orders = []; };

private _bestAt = -1;
{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
    if (!(_tg isEqualTo _gid)) then { continue; };
    if (!(toUpper _st isEqualTo "ISSUED")) then { continue; };
    if (!(_iat isEqualType 0)) then { continue; };
    if (_iat > _bestAt) then { _bestAt = _iat; _orderId = _oid; };
} forEach _orders;

if (!(_orderId isEqualType "")) then { _orderId = ""; };
_orderId = trim _orderId;

// STAGED branch (new order): order issued now, incident closes later via acceptance trigger in fn_intelOrderAccept.
["activeIncidentClosePending", true] call ARC_fnc_stateSet;
["activeIncidentClosePendingAt", serverTime] call ARC_fnc_stateSet;
["activeIncidentClosePendingResult", _closeResult] call ARC_fnc_stateSet;
["activeIncidentClosePendingOrderId", _orderId] call ARC_fnc_stateSet;
["activeIncidentClosePendingGroup", _gid] call ARC_fnc_stateSet;

// Ensure execution is halted while waiting for acceptance
["activeIncidentCloseReady", true] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_activeIncidentClosePending", true, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", serverTime, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", _closeResult, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", _orderId, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", _gid, true];
missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];

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
