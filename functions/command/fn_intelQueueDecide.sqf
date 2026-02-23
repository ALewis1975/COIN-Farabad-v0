/*
    ARC_fnc_intelQueueDecide

    Server: approve / reject a pending TOC queue request.

    Params:
      0: OBJECT approver
      1: STRING queueId (ARC_q_#)
      2: BOOL   approve
      3: STRING note (optional)

    Returns:
      BOOL (true if updated)
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

params [
    ["_approver", objNull],
    ["_qid", ""],
    ["_approve", false],
    ["_note", ""]
];

// RemoteExec-only validation path: requires remoteExecutedOwner context.
if (!([_approver, "ARC_fnc_intelQueueDecide", "Queue decision rejected: sender verification failed.", "TOC_QUEUE_DECIDE_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!(_qid isEqualType "")) then { _qid = ""; };
_qid = trim _qid;
if (_qid isEqualTo "") exitWith {false};

if (!(_approve isEqualType true)) then { _approve = false; };
if (!(_note isEqualType "")) then { _note = ""; };

private _by = "SYSTEM";
if (!isNull _approver) then { _by = [_approver] call ARC_fnc_rolesFormatUnit; };

private _q = ["tocQueue", []] call ARC_fnc_stateGet;
if (!(_q isEqualType [])) exitWith {false};

private _idx = -1;
for "_i" from 0 to ((count _q) - 1) do
{
    private _it = _q # _i;
    if (_it isEqualType [] && { (count _it) >= 12 } && { (_it # 0) isEqualTo _qid }) exitWith
    {
        _idx = _i;
    };
};

if (_idx < 0) exitWith {false};

private _item = _q # _idx;
_item params [
    "_id",
    "_createdAt",
    "_status",
    "_kind",
    "_from",
    "_fromGroup",
    "_fromUID",
    "_posATL",
    "_summary",
    "_details",
    "_payload",
    "_meta",
    ["_decision", []]
];

// Server-side authority check (do not rely on client-side addAction gating)
if (!isNull _approver) then
{
    if (!([_approver] call ARC_fnc_rolesCanApproveQueue)) exitWith
    {
        ["OPS", format ["QUEUE: %1 attempted to decide %2 (%3) - DENIED (not authorized).", _by, _id, (toUpper _kind)], _posATL,
            [
                ["event", "TOC_QUEUE_DENIED"],
                ["queueId", _id],
                ["kind", (toUpper _kind)],
                ["by", _by]
            ]
        ] call ARC_fnc_intelLog;
        false
    };
};

if (!(_status isEqualType "") || { toUpper _status isNotEqualTo "PENDING" }) exitWith {false};

private _newStatus = if (_approve) then {"APPROVED"} else {"REJECTED"};
private _dec = [serverTime, _by, _approve, trim _note];

// Update the queue item
_item set [2, _newStatus];
_item set [12, _dec];
_q set [_idx, _item];
["tocQueue", _q] call ARC_fnc_stateSet;

// Broadcast pending-only snapshot
[] call ARC_fnc_intelQueueBroadcast;

// Helper: pull a value from payload pairs
private _getP = {
    params ["_pairs", "_k", "_d"]; 
    if (!(_pairs isEqualType [])) exitWith { _d };
    private _out = _d;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith
        {
            _out = _x # 1;
        };
    } forEach _pairs;
    _out
};

// Helper: set or replace a key/value pair in a meta "pairs" array
private _setPair = {
    params ["_pairs", "_k", "_v"];

    if (!(_pairs isEqualType [])) then { _pairs = []; };
    if (!(_k isEqualType "")) then { _k = str _k; };

    private _idx = _pairs findIf {
        (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }
    };

    if (_idx < 0) then
    {
        _pairs pushBack [_k, _v];
    }
    else
    {
        _pairs set [_idx, [_k, _v]];
    };

    _pairs
};


private _kindU = toUpper _kind;

if (_approve) then
{
    switch (_kindU) do
    {
        case "LEAD_REQUEST":
        {
            private _leadType = [_payload, "leadType", "RECON"] call _getP;
            private _disp     = [_payload, "displayName", _summary] call _getP;
            private _strength = [_payload, "strength", 0.55] call _getP;
            private _ttl      = [_payload, "ttl", 3600] call _getP;
            private _tag      = [_payload, "tag", "S2_REQUEST"] call _getP;

            private _pri      = [_payload, "priority", 3] call _getP;

            if (!(_leadType isEqualType "")) then { _leadType = "RECON"; };
            _leadType = toUpper (trim _leadType);

            if (!(_disp isEqualType "")) then { _disp = _summary; };
            _disp = trim _disp;
            if (_disp isEqualTo "") then { _disp = "Lead: S2 Requested Collection"; };
            if ((toLower _disp) find "lead:" isNotEqualTo 0) then { _disp = format ["Lead: %1", _disp]; };

            if (!(_strength isEqualType 0)) then { _strength = 0.55; };
            _strength = (_strength max 0.05) min 0.95;

            if (!(_ttl isEqualType 0)) then { _ttl = 3600; };
            _ttl = (_ttl max (10*60)) min (6*60*60);

            if (!(_tag isEqualType "")) then { _tag = "S2_REQUEST"; };
            _tag = trim _tag;
            if (_tag isEqualTo "") then { _tag = "S2_REQUEST"; };

            if (!(_pri isEqualType 0)) then { _pri = 3; };
            _pri = round _pri;
            _pri = (_pri max 1) min 5;


            // Create a lead that the incident generator will prefer (tagged), and
            // carry the queueId for traceability.
            private _lid = [_leadType, _disp, _posATL, _strength, _ttl, _id, "QUEUE", "", _tag] call ARC_fnc_leadCreate;
            if (!(_lid isEqualType "")) then { _lid = ""; };

            // Attach the created leadId to the queue item's meta so client UIs can track it after approval.
            if (_lid isEqualTo "") then
            {
                // no-op
            }
            else
            {
                _meta = [_meta, "leadId", _lid] call _setPair;
                _item set [11, _meta];
                _q set [_idx, _item];
                ["tocQueue", _q] call ARC_fnc_stateSet;
                [] call ARC_fnc_intelQueueBroadcast;
            };


            // Enqueue into TOC backlog so the next incident generator can prefer this approved lead.
            if (!isNil "ARC_fnc_tocBacklogEnqueue" && { _lid isEqualType "" } && { _lid isNotEqualTo "" }) then
            {
                [_lid, _pri, _id, _by, _summary] call ARC_fnc_tocBacklogEnqueue;
            };

            ["OPS", format ["QUEUE: %1 approved %2 (%3). Lead %4 created.", _by, _id, _kindU, _lid], _posATL,
                [
                    ["event", "TOC_QUEUE_APPROVED"],
                    ["queueId", _id],
                    ["kind", _kindU],
                    ["leadId", _lid],
                    ["leadType", _leadType],
                    ["from", _from],
                    ["fromGroup", _fromGroup]
                ]
            ] call ARC_fnc_intelLog;
        };

        case "FOLLOWON_PACKAGE":
        {
            // Post-closeout follow-on package: mark leadIds as TOC-triaged.
            private _leadIds = [_payload, "leadIds", []] call _getP;
            if (!(_leadIds isEqualType [])) then { _leadIds = []; };

            private _approved = [];
            {
                if (_x isEqualType "") then
                {
                    private _lid = trim _x;
                    if (_lid isNotEqualTo "") then { _approved pushBackUnique _lid; };
                };
            } forEach _leadIds;

            // Record approvals in server state (does not issue orders / does not activate incidents).
            private _appr = ["tocLeadApprovals", []] call ARC_fnc_stateGet;
            if (!(_appr isEqualType [])) then { _appr = []; };

            {
                _appr pushBack [_x, serverTime, _by, _id];
            } forEach _approved;

            // Cap to avoid unbounded growth.
            private _cap = 200;
            if ((count _appr) > _cap) then { _appr = _appr select [((count _appr) - _cap) max 0, _cap]; };
            ["tocLeadApprovals", _appr] call ARC_fnc_stateSet;

            // Attach approvedLeadIds to the queue item for UI traceability.
            _meta = [_meta, "approvedLeadIds", _approved] call _setPair;
            _item set [11, _meta];
            _q set [_idx, _item];
            ["tocQueue", _q] call ARC_fnc_stateSet;
            [] call ARC_fnc_intelQueueBroadcast;


            // Enqueue each approved lead into TOC backlog (priority default 3 unless overridden later).
            if (!isNil "ARC_fnc_tocBacklogEnqueue") then
            {
                {
                    if (_x isEqualType "" && { _x isNotEqualTo "" }) then
                    {
                        [_x, 3, _id, _by, _summary] call ARC_fnc_tocBacklogEnqueue;
                    };
                } forEach _approved;
            };

            ["OPS", format ["QUEUE: %1 approved %2 (%3). TOC triaged leads: %4", _by, _id, _kindU, if ((count _approved) > 0) then { _approved joinString ", " } else { "None" }], _posATL,
                [
                    ["event", "TOC_QUEUE_APPROVED"],
                    ["queueId", _id],
                    ["kind", _kindU],
                    ["approvedLeadIds", _approved],
                    ["from", _from],
                    ["fromGroup", _fromGroup]
                ]
            ] call ARC_fnc_intelLog;
        };


        case "FOLLOWON_REQUEST":
        {
            private _req = [_payload, "request", "RTB"] call _getP;
            private _purpose = [_payload, "purpose", "REFIT"] call _getP;
            private _note2 = [_payload, "note", ""] call _getP;

            private _rationale = [_payload, "rationale", ""] call _getP;
            private _constraints = [_payload, "constraints", ""] call _getP;
            private _support = [_payload, "support", ""] call _getP;
            private _holdIntent = [_payload, "holdIntent", ""] call _getP;
            private _holdMinutes = [_payload, "holdMinutes", 0] call _getP;
            private _proceedIntent = [_payload, "proceedIntent", ""] call _getP;

            if (!(_req isEqualType "")) then { _req = "RTB"; };
            _req = toUpper (trim _req);
            if !(_req in ["RTB","HOLD","PROCEED"]) then { _req = "RTB"; };

            if (!(_purpose isEqualType "")) then { _purpose = "REFIT"; };
            _purpose = toUpper (trim _purpose);
            if !(_purpose in ["REFIT","INTEL","EPW"]) then { _purpose = "REFIT"; };

            if (!(_note2 isEqualType "")) then { _note2 = ""; };
            if (!(_rationale isEqualType "")) then { _rationale = ""; };
            if (!(_constraints isEqualType "")) then { _constraints = ""; };
            if (!(_support isEqualType "")) then { _support = ""; };
            if (!(_holdIntent isEqualType "")) then { _holdIntent = ""; };
            if (!(_proceedIntent isEqualType "")) then { _proceedIntent = ""; };
            if (!(_holdMinutes isEqualType 0)) then { _holdMinutes = 0; };
            _holdMinutes = (_holdMinutes max 0) min 240;

            private _seed = [];
            if (trim _rationale isNotEqualTo "") then { _seed pushBack ["rationale", trim _rationale]; };
            if (trim _constraints isNotEqualTo "") then { _seed pushBack ["constraints", trim _constraints]; };
            if (trim _support isNotEqualTo "") then { _seed pushBack ["support", trim _support]; };

            private _issueOk = false;

            switch (_req) do
            {
                case "RTB":
                {
                    _seed pushBack ["purpose", _purpose];
                    _issueOk = ["RTB", _fromGroup, _seed, _approver, _note2, _id] call ARC_fnc_intelOrderIssue;
                };

                case "HOLD":
                {
                    _seed pushBack ["purpose", "HOLD"];
                    if (trim _holdIntent isNotEqualTo "") then { _seed pushBack ["holdIntent", trim _holdIntent]; };
                    if (_holdMinutes > 0) then { _seed pushBack ["holdMinutes", _holdMinutes]; };
                    _issueOk = ["HOLD", _fromGroup, _seed, _approver, _note2, _id] call ARC_fnc_intelOrderIssue;
                };

                case "PROCEED":
                {
                    // PROCEED becomes a LEAD assignment when possible; otherwise STANDBY.
                    if (trim _proceedIntent isNotEqualTo "") then { _seed pushBack ["proceedIntent", trim _proceedIntent]; };
                    _issueOk = ["LEAD", _fromGroup, _seed, _approver, _note2, _id] call ARC_fnc_intelOrderIssue;
                };

                default
                {
                    _seed pushBack ["purpose", _purpose];
                    _issueOk = ["RTB", _fromGroup, _seed, _approver, _note2, _id] call ARC_fnc_intelOrderIssue;
                };
            };

            ["OPS", format ["QUEUE: %1 approved %2 (%3) -> %4 order (%5).", _by, _id, _kindU, _req, _fromGroup], _posATL,
                [
                    ["event", "TOC_QUEUE_APPROVED"],
                    ["queueId", _id],
                    ["kind", _kindU],
                    ["request", _req],
                    ["purpose", _purpose],
                    ["targetGroup", _fromGroup],
                    ["issued", _issueOk]
                ]
            ] call ARC_fnc_intelLog;
        };

        case "EOD_DISPO_REQUEST":
        {
            private _taskId = [_payload, "taskId", ""] call _getP;
            if (!(_taskId isEqualType "")) then { _taskId = ""; };
            _taskId = trim _taskId;

            private _reqType = [_payload, "requestType", "DET_IN_PLACE"] call _getP;
            if (!(_reqType isEqualType "")) then { _reqType = "DET_IN_PLACE"; };
            _reqType = toUpper (trim _reqType);
            if !(_reqType in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"]) then { _reqType = "DET_IN_PLACE"; };

            private _notes = [_payload, "notes", ""] call _getP;
            if (!(_notes isEqualType "")) then { _notes = ""; };
            _notes = trim _notes;

            private _ttl = missionNamespace getVariable ["ARC_eodDispoApprovalTTLsec", 900];
            if (!(_ttl isEqualType 0)) then { _ttl = 900; };
            _ttl = (_ttl max 60) min (60*60);

            private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
            if (!(_appr isEqualType [])) then { _appr = []; };

            private _exp = serverTime + _ttl;
            _appr pushBack [_taskId, _fromGroup, _reqType, serverTime, _by, _exp, _notes];

            // Cap to avoid unbounded growth.
            private _cap = 50;
            if ((count _appr) > _cap) then { _appr = _appr select [((count _appr) - _cap) max 0, _cap]; };
            ["eodDispoApprovals", _appr] call ARC_fnc_stateSet;

            // Broadcast for clients
            [] call ARC_fnc_iedDispoBroadcast;

            // Tag queue item with a reference (for TOC UI traceability)
            _meta = [_meta, "eodApproval", format ["%1|%2|%3", _taskId, _fromGroup, _reqType]] call _setPair;
            _item set [11, _meta];
            _q set [_idx, _item];
            ["tocQueue", _q] call ARC_fnc_stateSet;
            [] call ARC_fnc_intelQueueBroadcast;

            ["OPS", format ["QUEUE: %1 approved %2 (%3) -> %4 for %5 (expires %6s).", _by, _id, _kindU, _reqType, _fromGroup, _ttl], _posATL,
                [
                    ["event", "TOC_QUEUE_APPROVED"],
                    ["queueId", _id],
                    ["kind", _kindU],
                    ["requestType", _reqType],
                    ["taskId", _taskId],
                    ["targetGroup", _fromGroup]
                ]
            ] call ARC_fnc_intelLog;
        };

        case "INCIDENT":
        {
            // Seeded/system incident queue item: activate the specific incident payload.
            private _markerRaw = [_payload, "marker", ""] call _getP;
            private _incidentType = [_payload, "incidentType", ""] call _getP;
            private _displayName = [_payload, "displayName", _summary] call _getP;
            private _payloadPosATL = [_payload, "pos", _posATL] call _getP;

            if (!(_markerRaw isEqualType "")) then { _markerRaw = ""; };
            if (!(_incidentType isEqualType "")) then { _incidentType = ""; };
            if (!(_displayName isEqualType "")) then { _displayName = _summary; };
            if (!(_payloadPosATL isEqualType [])) then { _payloadPosATL = _posATL; };

            _markerRaw = trim _markerRaw;
            _incidentType = toUpper (trim _incidentType);
            _displayName = trim _displayName;
            if (_displayName isEqualTo "") then { _displayName = "Seeded Incident"; };

            private _spawned = false;
            private _spawnReason = "";
            private _taskId = "";

            private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
            if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };

            if (_activeTaskId isNotEqualTo "") then
            {
                _spawnReason = format ["active incident already set (%1)", _activeTaskId];
            }
            else
            {
                if (_markerRaw isEqualTo "") then
                {
                    _spawnReason = "missing marker in payload";
                }
                else
                {
                    private _markerResolved = [_markerRaw] call ARC_fnc_worldResolveMarker;
                    if !(_markerResolved in allMapMarkers) then
                    {
                        _spawnReason = format ["marker not found (%1)", _markerRaw];
                    }
                    else
                    {
                        if (_incidentType isEqualTo "") then { _incidentType = "LOGISTICS"; };

                        private _pos = + (getMarkerPos _markerResolved);
                        if (_payloadPosATL isEqualType [] && { (count _payloadPosATL) >= 2 }) then
                        {
                            _pos = +_payloadPosATL;
                        };
                        _pos resize 3;

                        private _zone = [_markerRaw] call ARC_fnc_worldGetZoneForMarker;
                        private _counter = ["taskCounter", 0] call ARC_fnc_stateGet;
                        if (!(_counter isEqualType 0)) then { _counter = 0; };
                        _counter = _counter + 1;
                        ["taskCounter", _counter] call ARC_fnc_stateSet;
                        _taskId = format ["ARC_inc_%1", _counter];

                        ["activeTaskId", _taskId] call ARC_fnc_stateSet;
                        ["activeIncidentType", _incidentType] call ARC_fnc_stateSet;
                        ["activeIncidentMarker", _markerRaw] call ARC_fnc_stateSet;
                        ["activeIncidentDisplayName", _displayName] call ARC_fnc_stateSet;
                        ["activeIncidentCreatedAt", serverTime] call ARC_fnc_stateSet;
                        ["activeIncidentZone", _zone] call ARC_fnc_stateSet;
                        ["activeIncidentPos", _pos] call ARC_fnc_stateSet;

                        ["activeIncidentAccepted", false] call ARC_fnc_stateSet;
                        ["activeIncidentAcceptedAt", -1] call ARC_fnc_stateSet;
                        ["activeIncidentAcceptedBy", ""] call ARC_fnc_stateSet;
                        ["activeIncidentAcceptedByName", ""] call ARC_fnc_stateSet;
                        ["activeIncidentAcceptedByUID", ""] call ARC_fnc_stateSet;
                        ["activeIncidentAcceptedByRoleTag", ""] call ARC_fnc_stateSet;
                        ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateSet;

                        ["activeIncidentSitrepSent", false] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepSentAt", -1] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepFrom", ""] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepFromUID", ""] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepFromRoleTag", ""] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepSummary", ""] call ARC_fnc_stateSet;
                        ["activeIncidentSitrepDetails", ""] call ARC_fnc_stateSet;

                        ["activeIncidentCloseReady", false] call ARC_fnc_stateSet;
                        ["activeIncidentSuggestedResult", ""] call ARC_fnc_stateSet;
                        ["activeIncidentCloseReason", ""] call ARC_fnc_stateSet;
                        ["activeIncidentCloseMarkedAt", -1] call ARC_fnc_stateSet;

                        ["activeLeadId", ""] call ARC_fnc_stateSet;
                        ["activeThreadId", ""] call ARC_fnc_stateSet;
                        ["activeLeadTag", ""] call ARC_fnc_stateSet;

                        ["activeExecTaskId", ""] call ARC_fnc_stateSet;
                        ["activeExecKind", ""] call ARC_fnc_stateSet;
                        ["activeExecPos", []] call ARC_fnc_stateSet;
                        ["activeExecRadius", 0] call ARC_fnc_stateSet;
                        ["activeExecStartedAt", -1] call ARC_fnc_stateSet;
                        ["activeExecDeadlineAt", -1] call ARC_fnc_stateSet;
                        ["activeExecArrivalReq", 0] call ARC_fnc_stateSet;
                        ["activeExecArrived", false] call ARC_fnc_stateSet;
                        ["activeExecHoldReq", 0] call ARC_fnc_stateSet;
                        ["activeExecHoldAccum", 0] call ARC_fnc_stateSet;
                        ["activeExecLastProg", -1] call ARC_fnc_stateSet;
                        ["activeExecLastProgressAt", -1] call ARC_fnc_stateSet;
                        ["activeObjectiveKind", ""] call ARC_fnc_stateSet;
                        ["activeObjectiveClass", ""] call ARC_fnc_stateSet;
                        ["activeObjectivePos", []] call ARC_fnc_stateSet;
                        ["activeObjectiveNetId", ""] call ARC_fnc_stateSet;

                        [_taskId, _markerRaw, _displayName, _incidentType, _pos, ""] call ARC_fnc_taskCreateIncident;

                        missionNamespace setVariable ["ARC_activeTaskId", _taskId, true];
                        missionNamespace setVariable ["ARC_activeIncidentMarker", _markerRaw, true];
                        missionNamespace setVariable ["ARC_activeIncidentType", _incidentType, true];
                        missionNamespace setVariable ["ARC_activeIncidentDisplayName", _displayName, true];
                        missionNamespace setVariable ["ARC_activeIncidentPos", _pos, true];
                        missionNamespace setVariable ["ARC_activeIncidentAccepted", false, true];
                        missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", -1, true];
                        missionNamespace setVariable ["ARC_activeIncidentAcceptedByGroup", "", true];

                        missionNamespace setVariable ["ARC_activeIncidentSitrepSent", false, true];
                        missionNamespace setVariable ["ARC_activeIncidentSitrepSentAt", -1, true];
                        missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", "", true];
                        missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", "", true];
                        missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", "", true];
                        missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", "", true];
                        missionNamespace setVariable ["ARC_activeIncidentCloseReady", false, true];
                        missionNamespace setVariable ["ARC_activeIncidentSuggestedResult", "", true];
                        missionNamespace setVariable ["ARC_activeIncidentCloseReason", "", true];
                        missionNamespace setVariable ["ARC_activeIncidentCloseMarkedAt", -1, true];
                        missionNamespace setVariable ["ARC_activeLeadId", "", true];
                        missionNamespace setVariable ["ARC_activeThreadId", "", true];

                        [] call ARC_fnc_publicBroadcastState;

                        private _grid = mapGridPosition _pos;
                        [
                            "New Incident Pending Acceptance",
                            format ["%1 (%2) at %3. Accept the incident to start execution.", _displayName, _incidentType, _grid],
                            8
                        ] remoteExec ["ARC_fnc_clientToast", 0];

                        _spawned = true;
                    };
                };
            };

            _meta = [_meta, "incidentActivated", _spawned] call _setPair;
            if (_taskId isNotEqualTo "") then { _meta = [_meta, "taskId", _taskId] call _setPair; };
            if (_spawnReason isNotEqualTo "") then { _meta = [_meta, "activationError", _spawnReason] call _setPair; };
            _item set [11, _meta];
            _q set [_idx, _item];
            ["tocQueue", _q] call ARC_fnc_stateSet;
            [] call ARC_fnc_intelQueueBroadcast;

            if (_spawned) then
            {
                ["OPS", format ["QUEUE: %1 approved %2 (%3). Activated task %4 at %5.", _by, _id, _kindU, _taskId, _markerRaw], _posATL,
                    [
                        ["event", "TOC_QUEUE_APPROVED"],
                        ["queueId", _id],
                        ["kind", _kindU],
                        ["taskId", _taskId],
                        ["marker", _markerRaw],
                        ["incidentType", _incidentType]
                    ]
                ] call ARC_fnc_intelLog;
            }
            else
            {
                ["OPS", format ["QUEUE: %1 approved %2 (%3) but activation skipped: %4.", _by, _id, _kindU, _spawnReason], _posATL,
                    [
                        ["event", "TOC_QUEUE_APPROVED"],
                        ["queueId", _id],
                        ["kind", _kindU],
                        ["activationError", _spawnReason],
                        ["marker", _markerRaw],
                        ["incidentType", _incidentType]
                    ]
                ] call ARC_fnc_intelLog;
            };
        };

        default
        {
            ["OPS", format ["QUEUE: %1 approved %2 (%3). No handler.", _by, _id, _kindU], _posATL,
                [
                    ["event", "TOC_QUEUE_APPROVED"],
                    ["queueId", _id],
                    ["kind", _kindU]
                ]
            ] call ARC_fnc_intelLog;
        };
    };
}
else
{
    ["OPS", format ["QUEUE: %1 rejected %2 (%3).", _by, _id, _kindU], _posATL,
        [
            ["event", "TOC_QUEUE_REJECTED"],
            ["queueId", _id],
            ["kind", _kindU],
            ["from", _from],
            ["fromGroup", _fromGroup]
        ]
    ] call ARC_fnc_intelLog;
};

true
