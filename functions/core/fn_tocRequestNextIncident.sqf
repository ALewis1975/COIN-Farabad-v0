/*
    Server: manually trigger incident generation.

    - If no incident is active: create one.
    - If an incident is active but task is missing: rehydrate it.

    Optional behavior:
      - If ARC_allowIncidentDuringAcceptedRtb is FALSE (default), block generation while the
        last tasked group has an ACCEPTED RTB order in progress.
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [ ["_caller", objNull, [objNull]] ];

private _owner = -1;
if (!isNil "remoteExecutedOwner") then { _owner = remoteExecutedOwner; };

private _remoteOwnerDbg = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
diag_log format [
    "[ARC][RPCDBG] NextIncident callerNull=%1 caller=%2 isPlayer=%3 callerOwner=%4 remoteExecutedOwner=%5 uid=%6",
    isNull _caller,
    if (isNull _caller) then {"<null>"} else {name _caller},
    if (isNull _caller) then {false} else {isPlayer _caller},
    if (isNull _caller) then {-1} else {owner _caller},
    _remoteOwnerDbg,
    if (isNull _caller) then {""} else {getPlayerUID _caller}
];

private _publishResult = {
    params [
        ["_ownerId", -1, [0]],
        ["_resultCode", "UNKNOWN", [""]],
        ["_title", "TOC", [""]],
        ["_detail", "", [""]],
        ["_allowed", false, [true]]
    ];

private _trimFn = compile "params ['_s']; trim _s";


    private _stamp = diag_tickTime;
    missionNamespace setVariable [
        "ARC_pub_nextIncidentResult",
        [_stamp, _ownerId, toUpper (([_resultCode] call _trimFn)), _title, _detail, _allowed],
        true
    ];

    if (!_allowed) then
    {
        missionNamespace setVariable [
            "ARC_pub_nextIncidentLastDenied",
            [_stamp, toUpper (([_resultCode] call _trimFn)), _detail],
            true
        ];
    };
};

// RemoteExec-only validation path: requires remoteExecutedOwner context.
private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
if (!([_caller, "ARC_fnc_tocRequestNextIncident", "Incident generation rejected: sender verification failed.", "TOC_NEXT_INCIDENT_SECURITY_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith
{
    if (_owner > 0) then
    {
        ["Incident generation blocked", "Security validation failed for this request.", 7] remoteExec ["ARC_fnc_clientToast", _owner];
        [
            _owner,
            "SECURITY_DENIED",
            "Incident generation blocked",
            "Security validation failed for this request.",
            false
        ] call _publishResult;
    };

    false
};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;

// Manual override: ensure auto-incident suppression doesn't block deliberate testing.
["autoIncidentSuspendUntil", -1] call ARC_fnc_stateSet;

if (_taskId isEqualTo "") then
{
    private _allowDuringRtb = missionNamespace getVariable ["ARC_allowIncidentDuringAcceptedRtb", false];

    if (!_allowDuringRtb) then
    {
        private _lastG = ["lastTaskingGroup", ""] call ARC_fnc_stateGet;
        private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
        if (!(_orders isEqualType [])) then { _orders = []; };

        private _hasAcceptedRtb = false;
        private _hasIssuedOrder = false;

        if (_lastG != "") then
        {
            {
                if (_x isEqualType [] && { (count _x) >= 5 }) then
                {
                    private _st = toUpper (_x select 2);
                    private _typ = toUpper (_x select 3);
                    private _tg = _x select 4;

                    // Any ISSUED order for the last tasked group should block new incident creation.
                    // This enforces the command cycle: TOC issues -> unit accepts -> execute.
                    if (_st isEqualTo "ISSUED" && { _tg isEqualTo _lastG }) exitWith
                    {
                        _hasIssuedOrder = true;
                    };

                    if (_st isEqualTo "ACCEPTED" && { _typ isEqualTo "RTB" } && { _tg isEqualTo _lastG }) exitWith
                    {
                        _hasAcceptedRtb = true;
                    };
                };
            } forEach _orders;
        };

        if (_hasIssuedOrder) exitWith
        {
            private _msg = format [
                "TOC: Incident generation blocked. %1 has a TOC order pending acceptance.",
                _lastG
            ];

            [
                "OPS",
                _msg,
                [0,0,0],
                [["event", "INCIDENT_GEN_BLOCKED"], ["reason", "ORDER_PENDING_ACCEPT"], ["group", _lastG]]
            ] call ARC_fnc_intelLog;

            if (_owner > 0) then
            {
                ["Incident generation blocked", format ["%1 has an order pending acceptance.", _lastG], 7] remoteExec ["ARC_fnc_clientToast", _owner];
                _msg remoteExec ["systemChat", _owner];
                [
                    _owner,
                    "ORDER_PENDING_ACCEPT",
                    "Incident generation blocked",
                    format ["%1 has an order pending acceptance.", _lastG],
                    false
                ] call _publishResult;
            };

            false
        };

        if (_hasAcceptedRtb) exitWith
        {
            private _msg = format [
                "TOC: Incident generation blocked. %1 has an accepted RTB order in progress.",
                _lastG
            ];

            // Log to OPS feed for traceability.
            [
                "OPS",
                _msg,
                [0,0,0],
                [["event", "INCIDENT_GEN_BLOCKED"], ["reason", "RTB_ACTIVE"], ["group", _lastG]]
            ] call ARC_fnc_intelLog;

            // Best-effort feedback to the requestor.
            if (_owner > 0) then
            {
                ["Incident generation blocked", format ["%1 has an accepted RTB order in progress.", _lastG], 7] remoteExec ["ARC_fnc_clientToast", _owner];
                _msg remoteExec ["systemChat", _owner];
                [
                    _owner,
                    "RTB_ACTIVE",
                    "Incident generation blocked",
                    format ["%1 has an accepted RTB order in progress.", _lastG],
                    false
                ] call _publishResult;
            };

            false
        };
    };

    // Consume the highest-priority approved lead from the TOC Queue (backlog) to
    // seed the next incident. The pop happens here, AFTER all blocking guards
    // (RTB/ISSUED-order checks above), so a blocked request never silently drains
    // the backlog. PopNext already prunes entries whose lead has aged out of the
    // pool, so any returned leadId resolves to a live lead that incidentCreate
    // consumes via ARC_fnc_leadConsumeById.
    //
    // forceLogistics is passed false here (minimal change): incidentCreate still
    // applies its own supply-critical filter once a lead is seeded. A future
    // follow-up could compute the real supply-critical flag here and pass it so
    // the backlog won't surface a non-logistics lead while base stocks are critical.
    private _seedLeadId = "";
    if (!isNil "ARC_fnc_tocBacklogPopNext") then
    {
        private _trimFn2 = compile "params ['_s']; trim _s";
        private _picked = [false] call ARC_fnc_tocBacklogPopNext;
        if (_picked isEqualType [] && { (count _picked) >= 1 } && { (_picked select 0) isEqualType "" }) then
        {
            _seedLeadId = ([_picked select 0] call _trimFn2);
        };
    };

    [_seedLeadId] call ARC_fnc_incidentCreate;

    if (_owner > 0) then
    {
        [
            _owner,
            "OK_GENERATED",
            "Incident generation",
            "Server approved your request and generated the next incident.",
            true
        ] call _publishResult;
    };

    true
}
else
{
    // Active exists; ensure the task framework still has it.
    [] call ARC_fnc_taskRehydrateActive;

    if (_owner > 0) then
    {
        [
            _owner,
            "OK_REHYDRATED",
            "Incident generation",
            "An incident is already active. Server rehydrated the active task state.",
            true
        ] call _publishResult;
    };

    true
}
