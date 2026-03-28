/*
    ARC_fnc_intelQueueSubmit

    Server: add a request into the TOC queue.

    Queue item format:
      [
        0: STRING  queueId (ARC_q_#)
        1: NUMBER  createdAt (serverTime)
        2: STRING  status (PENDING|APPROVED|REJECTED)
        3: STRING  kind (LEAD_REQUEST|FOLLOWON_REQUEST|...)
        4: STRING  from (formatted unit)
        5: STRING  fromGroup (groupId)
        6: STRING  fromUID
        7: ARRAY   posATL
        8: STRING  summary
        9: STRING  details
        10: ARRAY  payload (kind-specific)
        11: ARRAY  metaPairs [[k,v],...]
        12: ARRAY  decision [decidedAt, decidedBy, approvedBool, note]
      ]

    Params:
      0: OBJECT requestor
      1: STRING kind
      2: ARRAY  payload
      3: STRING summary (optional)
      4: STRING details (optional)
      5: ARRAY  posATL  (optional)
      6: ARRAY  metaPairsExtra (optional)

    Returns:
      STRING queueId ("" on failure)
*/

if (!isServer) exitWith {""};

params [
    ["_requestor", objNull],
    ["_kind", ""],
    ["_payload", []],
    ["_summary", ""],
    ["_details", ""],
    ["_pos", []],
    ["_metaExtra", []]
];

private _trimFn = compile "params ['_s']; trim _s";

if (!(_kind isEqualType "")) then { _kind = ""; };
_kind = toUpper ([_kind] call _trimFn);
if (_kind isEqualTo "") exitWith {""};

// Dedicated MP hardening: validate sender when requestor is provided.
if (!isNil "remoteExecutedOwner" && { !isNull _requestor }) then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _requestor) != _reo) exitWith
        {
            diag_log format ["[ARC][SEC] %1 denied: sender-owner mismatch reo=%2 requestorOwner=%3 requestor=%4",
                "ARC_fnc_intelQueueSubmit", _reo, owner _requestor, name _requestor];
            ""
        };
    };
};

if (!(_payload isEqualType [])) then { _payload = []; };
if (!(_summary isEqualType "")) then { _summary = ""; };
if (!(_details isEqualType "")) then { _details = ""; };
if (!(_metaExtra isEqualType [])) then { _metaExtra = []; };

private _posATL = _pos;
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) then { _posATL = []; };
if (_posATL isEqualTo [] && { !isNull _requestor }) then { _posATL = getPosATL _requestor; };
if (_posATL isEqualTo []) then { _posATL = [0,0,0]; };
_posATL resize 3;

private _from = "SYSTEM";
private _fromUID = "";
private _fromGroup = "";

if (!isNull _requestor) then
{
    _from = [_requestor] call ARC_fnc_rolesFormatUnit;
    _fromUID = getPlayerUID _requestor;
    _fromGroup = groupId (group _requestor);
};

private _grid = mapGridPosition _posATL;
private _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;
if (_zone isEqualTo "") then { _zone = "Unzoned"; };

private _meta = [
    ["grid", _grid],
    ["zone", _zone],
    ["kind", _kind]
];

// Merge meta extras
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then
    {
        _meta pushBack [_x select 0, _x select 1];
    };
} forEach _metaExtra;

// Server-side validation for specific queue kinds (prevents client-side desync / abuse)
private _getP =
{
    params ["_pairs", "_k", "_d"];
    private _v = _d;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _v = _x select 1; };
    } forEach _pairs;
    _v
};

if (_kind isEqualTo "FOLLOWON_REQUEST") then
{
    private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
    private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };
    if (!(_taskId isEqualType "")) then { _taskId = ""; };

    if (!_sitrepSent || { _taskId isEqualTo "" }) exitWith
    {
        if (!isNull _requestor) then
        {
            ["FOLLOW-ON", "Send a close-out SITREP before requesting follow-on orders."] remoteExec ["ARC_fnc_clientToast", owner _requestor];
        };

        ["OPS", format ["QUEUE: rejected FOLLOWON_REQUEST from %1 (SITREP required).", _from], _posATL,
            [
                ["event", "TOC_QUEUE_REJECT"],
                ["kind", _kind],
                ["from", _from],
                ["fromGroup", _fromGroup],
                ["reason", "SITREP_REQUIRED"]
            ]
        ] call ARC_fnc_intelLog;
        ""
    };

    private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
    if (!(_orders isEqualType [])) then { _orders = []; };

    private _pending = false;
    {
        if (_x isEqualType [] && { (count _x) >= 7 }) then
        {
            private _st = toUpper (_x select 2);
            private _tgt = _x select 4;
            if (_st isEqualTo "ISSUED" && { _tgt isEqualTo _fromGroup }) exitWith { _pending = true; };
        };
    } forEach _orders;

    if (_pending) exitWith
    {
        if (!isNull _requestor) then
        {
            ["FOLLOW-ON", "You have a TOC order pending acceptance. Accept it before requesting another follow-on."] remoteExec ["ARC_fnc_clientToast", owner _requestor];
        };

        ["OPS", format ["QUEUE: rejected FOLLOWON_REQUEST from %1 (order pending acceptance).", _from], _posATL,
            [
                ["event", "TOC_QUEUE_REJECT"],
                ["kind", _kind],
                ["from", _from],
                ["fromGroup", _fromGroup],
                ["reason", "ORDER_PENDING_ACCEPTANCE"]
            ]
        ] call ARC_fnc_intelLog;
        ""
    };
};

if (_kind isEqualTo "EOD_DISPO_REQUEST") then
{
    // Require an active IED incident matching the request payload.
    private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (!(_taskId isEqualType "")) then { _taskId = ""; };
    _taskId = [_taskId] call _trimFn;

    private _typ = ["activeIncidentType", ""] call ARC_fnc_stateGet;
    if (!(_typ isEqualType "")) then { _typ = ""; };
    _typ = toUpper ([_typ] call _trimFn);

    private _reqTask = [_payload, "taskId", ""] call _getP;
    if (!(_reqTask isEqualType "")) then { _reqTask = ""; };
    _reqTask = [_reqTask] call _trimFn;

    private _reqType = [_payload, "requestType", "DET_IN_PLACE"] call _getP;
    if (!(_reqType isEqualType "")) then { _reqType = "DET_IN_PLACE"; };
    _reqType = toUpper ([_reqType] call _trimFn);
    if !(_reqType in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"]) then { _reqType = "DET_IN_PLACE"; };

    if (_taskId isEqualTo "" || { _reqTask isEqualTo "" } || { !(_reqTask isEqualTo _taskId) } || { !(_typ isEqualTo "IED") }) exitWith
    {
        if (!isNull _requestor) then
        {
            ["EOD", "EOD disposition requests require an active IED incident."] remoteExec ["ARC_fnc_clientToast", owner _requestor];
        };

        ["OPS", format ["QUEUE: rejected EOD_DISPO_REQUEST from %1 (no active IED incident).", _from], _posATL,
            [
                ["event", "TOC_QUEUE_REJECT"],
                ["kind", _kind],
                ["from", _from],
                ["fromGroup", _fromGroup],
                ["reason", "NO_ACTIVE_IED"],
                ["requestType", _reqType]
            ]
        ] call ARC_fnc_intelLog;
        ""
    };
};

private _ctr = ["queueCounter", 0] call ARC_fnc_stateGet;
if (!(_ctr isEqualType 0)) then { _ctr = 0; };
_ctr = _ctr + 1;
["queueCounter", _ctr] call ARC_fnc_stateSet;

private _qid = format ["ARC_q_%1", _ctr];

private _item = [
    _qid,
    serverTime,
    "PENDING",
    _kind,
    _from,
    _fromGroup,
    _fromUID,
    _posATL,
    [_summary] call _trimFn,
    [_details] call _trimFn,
    _payload,
    _meta,
    []
];

private _q = ["tocQueue", []] call ARC_fnc_stateGet;
if (!(_q isEqualType [])) then { _q = []; };
_q pushBack _item;

private _cap = missionNamespace getVariable ["ARC_tocQueueCap", 30];
if (!(_cap isEqualType 0)) then { _cap = 30; };
_cap = (_cap max 10) min 100;

while { (count _q) > _cap } do
{
    _q deleteAt 0;
};

["tocQueue", _q] call ARC_fnc_stateSet;

// Broadcast pending-only snapshot
[] call ARC_fnc_intelQueueBroadcast;

// Log to OPS feed for TOC awareness
["OPS", format ["QUEUE: %1 submitted %2 (%3) Zone %4.", _from, _qid, _kind, _zone], _posATL,
    [
        ["event", "TOC_QUEUE_SUBMIT"],
        ["queueId", _qid],
        ["kind", _kind],
        ["from", _from],
        ["fromGroup", _fromGroup],
        ["grid", _grid],
        ["zone", _zone]
    ]
] call ARC_fnc_intelLog;

_qid
