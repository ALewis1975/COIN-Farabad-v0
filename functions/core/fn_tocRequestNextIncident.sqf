/*
    Server: manually trigger incident generation.

    - If no incident is active: create one.
    - If an incident is active but task is missing: rehydrate it.

    Optional behavior:
      - If ARC_allowIncidentDuringAcceptedRtb is FALSE (default), block generation while the
        last tasked group has an ACCEPTED RTB order in progress.
*/

if (!isServer) exitWith {false};

params [ ["_caller", objNull, [objNull]] ];

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
                    private _st = toUpper (_x # 2);
                    private _typ = toUpper (_x # 3);
                    private _tg = _x # 4;

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

            private _owner = remoteExecutedOwner;
            if (_owner > 0) then
            {
                ["Incident generation blocked", format ["%1 has an order pending acceptance.", _lastG], 7] remoteExec ["ARC_fnc_clientToast", _owner];
                _msg remoteExec ["systemChat", _owner];
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
            private _owner = remoteExecutedOwner;
            if (_owner > 0) then
            {
                _msg remoteExec ["systemChat", _owner];
            };

            false
        };
    };

    [] call ARC_fnc_incidentCreate;
    true
}
else
{
    // Active exists; ensure the task framework still has it.
    [] call ARC_fnc_taskRehydrateActive;
    true
}
