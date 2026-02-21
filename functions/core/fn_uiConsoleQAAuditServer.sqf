/*
    ARC_fnc_uiConsoleQAAuditServer

    Server-side QA audit for Farabad Console integration.
    Runs sanity checks (function presence, state coherence) and returns a report
    to the requesting client for display in the Headquarters tab.

    Called from client via HQ tab -> Execute.
*/

if (!isServer) exitWith { false };

params [
    ["_requester", objNull, [objNull]]
];

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

private _owner = 0;
if (!isNull _requester) then { _owner = owner _requester; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

private _lines = [];
private _nl = "<br/>";

private _pushCheck = {
    params ["_ok", "_name", ["_detail", ""]];
    private _c = if (_ok) then { "#6EE7B7" } else { "#FF6B6B" };
    _lines pushBack format ["<t color='%1'>%2</t> <t font='PuristaMedium'>%3</t>", _c, if (_ok) then {"PASS"} else {"FAIL"}, _name];
    if (_detail isEqualType "" && { !(_detail isEqualTo "") }) then
    {
        _lines pushBack format ["<t color='#BDBDBD' size='0.9'>%1</t>", _detail];
    };
    _lines pushBack "";
};

_lines pushBack "<t size='1.2' font='PuristaMedium'>Farabad Console QA Audit</t>";
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Server time:</t> <t size='0.9'>%1</t>", serverTime];
_lines pushBack "";

// --- Function presence (server) ---
_lines pushBack "<t size='1.05' font='PuristaMedium'>Functions</t>";

private _needFns = [
    ["ARC_fnc_tocRequestCloseoutAndOrder", "TOC closeout+order transaction"],
    ["ARC_fnc_tocReceiveSitrep", "TOC receive SITREP"],
    ["ARC_fnc_incidentClose", "Incident close"],
    ["ARC_fnc_taskRehydrateActive", "Task rehydrate active"],
    ["ARC_fnc_intelOrderIssue", "Issue order"],
    ["ARC_fnc_intelOrderBroadcast", "Broadcast orders"],
    ["ARC_fnc_stateGet", "State get"],
    ["ARC_fnc_stateSet", "State set"],
    ["ARC_fnc_stateSave", "State save"]
];

{
    _x params ["_fnName", "_label"];
    private _ok = !(isNil _fnName);
    [_ok, _label, _fnName] call _pushCheck;
} forEach _needFns;

// --- State coherence ---
_lines pushBack "";
_lines pushBack "<t size='1.05' font='PuristaMedium'>State coherence</t>";

private _incId = ["activeIncidentId", ""] call ARC_fnc_stateGet;
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
private _acceptedBy = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
private _closeReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
private _foQid = ["activeIncidentFollowOnQueueId", ""] call ARC_fnc_stateGet;
private _foReq = ["activeIncidentFollowOnRequest", []] call ARC_fnc_stateGet;

if (!(_incId isEqualType "")) then { _incId = ""; };
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (!(_acceptedBy isEqualType "")) then { _acceptedBy = ""; };
if (!(_foQid isEqualType "")) then { _foQid = ""; };
if (!(_foReq isEqualType [])) then { _foReq = []; };

_incId = [_incId] call _trimFn;
_taskId = [_taskId] call _trimFn;
_acceptedBy = [_acceptedBy] call _trimFn;
_foQid = [_foQid] call _trimFn;

[(_incId isEqualTo "") || { !(_taskId isEqualTo "") }, "Active incident has taskId", format ["activeIncidentId=%1 / activeTaskId=%2", _incId, _taskId]] call _pushCheck;
[(!_accepted) || { !(_acceptedBy isEqualTo "") }, "Accepted incident has acceptedBy group", format ["accepted=%1 / acceptedBy=%2", _accepted, _acceptedBy]] call _pushCheck;

private _foOk = true;
private _foDetail = "";
if (_sitrepSent && { _foReq isEqualType [] } && { (count _foReq) > 0 }) then
{
    _foOk = !(_foQid isEqualTo "");
    _foDetail = format ["followOnReqPairs=%1 / queueId=%2", count _foReq, _foQid];
};
[_foOk, "Follow-on request queued when submitted", _foDetail] call _pushCheck;

// --- Public state ---
_lines pushBack "";
_lines pushBack "<t size='1.05' font='PuristaMedium'>Public state</t>";

private _pubOrders = missionNamespace getVariable ["ARC_pub_orders", []];
private _pubQueue = missionNamespace getVariable ["ARC_pub_queuePending", []];

[(_pubOrders isEqualType []), "ARC_pub_orders is an array", format ["count=%1", if (_pubOrders isEqualType []) then { count _pubOrders } else { -1 }]] call _pushCheck;
[(_pubQueue isEqualType []), "ARC_pub_queuePending is an array", format ["count=%1", if (_pubQueue isEqualType []) then { count _pubQueue } else { -1 }]] call _pushCheck;

_lines pushBack "";
_lines pushBack "<t size='0.95' color='#BDBDBD'>If you see FAIL on any item above, grab the server RPT and the mission build stamp and report it.</t>";

// Build report
private _report = _lines joinString _nl;

// Log to server RPT (plain text)
diag_log "[ARC][QA] ===== Farabad Console QA Audit =====";
diag_log format ["[ARC][QA] activeIncidentId=%1 activeTaskId=%2 accepted=%3 acceptedBy=%4 closeReady=%5 sitrepSent=%6",
    _incId, _taskId, _accepted, _acceptedBy, _closeReady, _sitrepSent
];
diag_log format ["[ARC][QA] pubOrders=%1 pubQueuePending=%2", if (_pubOrders isEqualType []) then {count _pubOrders} else {-1}, if (_pubQueue isEqualType []) then {count _pubQueue} else {-1}];
diag_log "[ARC][QA] ===== End QA =====";

if (_owner > 0) then
{
    [_report] remoteExec ["ARC_fnc_uiConsoleQAAuditClientReceive", _owner];
};

true
