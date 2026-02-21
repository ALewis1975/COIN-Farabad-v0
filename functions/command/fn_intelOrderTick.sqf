/*
    ARC_fnc_intelOrderTick

    Server: periodic order maintenance.

    Currently:
      - Completes RTB orders when the target group reaches the destination.

    Intended cadence: called from ARC_fnc_incidentTick (1/min).

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType []) || { (count _orders) isEqualTo 0 }) exitWith {false};

// Helpers
private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    private _idx = [_pairs, {
        (_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith { _d };
    (_pairs select _idx) select 1
};

private _setPair = {
    params ["_pairs", "_k", "_v"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }
    }] call _findIfFn;
    if (_idx < 0) then { _pairs pushBack [_k, _v]; } else { _pairs set [_idx, [_k, _v]]; };
    _pairs
};

private _findGroup = {
    params ["_groupId"];
    private _g = grpNull;
    {
        if (groupId _x isEqualTo _groupId) exitWith { _g = _x; };
    } forEach allGroups;
    _g
};

private _changed = false;

for "_i" from 0 to ((count _orders) - 1) do
{
    private _o = _orders select _i;
    if (!(_o isEqualType []) || { (count _o) < 7 }) then { continue; };

    _o params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];
    _status = toUpper _status;
    _orderType = toUpper _orderType;

    if (!(_status isEqualTo "ACCEPTED")) then { continue; };

    if (_orderType isEqualTo "RTB") then
    {
        if (!(_data isEqualType [])) then { _data = []; };
        if (!(_meta isEqualType [])) then { _meta = []; };

        private _taskId = [_data, "taskId", ""] call _getPair;
        private _destPos = [_data, "destPos", []] call _getPair;
        private _destRad = [_data, "destRadius", 30] call _getPair;

        if (_taskId isEqualTo "") then { continue; };
        if (!(_destPos isEqualType []) || { (count _destPos) < 2 }) then { continue; };
        if (!(_destRad isEqualType 0)) then { _destRad = 30; };

        private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);

        // Intel debrief areas are wider than the physical board/TV objects; avoid false "not arrived".
        if (_purpose isEqualTo "INTEL") then { _destRad = _destRad max 30; };

        private _g = [_targetGroup] call _findGroup;
        if (isNull _g) then { continue; };

        private _arrived = false;

        if (_purpose isEqualTo "EPW") then
        {
            // EPW arrival is driven by the detainee being delivered to the processing point.
            // This avoids edge cases where the escorting player steps away but the EPW is already in the zone.
            private _searchRad = missionNamespace getVariable ["ARC_epwProcessSearchRadius", 45];
            if (!(_searchRad isEqualType 0)) then { _searchRad = 45; };
            _searchRad = (_searchRad max 10) min 200;

            {
                private _u = _x;

                if (isPlayer _u) then { continue; };
                if (!alive _u) then { continue; };
                if ((_u distance2D _destPos) > _searchRad) then { continue; };

                private _hc = _u getVariable ["ace_captives_isHandcuffed", false];
                if (!(_hc isEqualType true)) then { _hc = false; };
                private _hc2 = _u getVariable ["ACE_captives_isHandcuffed", false];
                if (!(_hc2 isEqualType true)) then { _hc2 = false; };

                private _isDetained = (captive _u) || { _hc } || { _hc2 };
                if (!_isDetained) then { continue; };

                _arrived = true;
                break;
            } forEach allUnits;
        }
        else
        {
            // IMPORTANT: only count human players for arrival. This prevents base-side AI (same group)
            // from prematurely triggering RTB arrival states.
            {
                if (isPlayer _x && { alive _x } && { (_x distance2D _destPos) <= _destRad }) exitWith { _arrived = true; };
            } forEach units _g;
        };

        if (_arrived) then
        {
            // RTB(INTEL|EPW): require an interaction at the station instead of auto-completing on arrival.
            if (_purpose in ["INTEL", "EPW"]) then
            {
                private _arrivedAt = [_meta, "arrivedAt", -1] call _getPair;
                if (!(_arrivedAt isEqualType 0)) then { _arrivedAt = -1; };

                if (_arrivedAt < 0) then
                {
                    _meta = [_meta, "arrivedAt", serverTime] call _setPair;
                    if (_purpose isEqualTo "INTEL") then
                    {
                        _meta = [_meta, "awaitingDebrief", true] call _setPair;
                    }
                    else
                    {
                        _meta = [_meta, "awaitingEpwProcessing", true] call _setPair;
                    };

                    // Keep status ACCEPTED until the debrief interaction completes it.
                    _orders set [_i, [_orderId, _issuedAt, _status, _orderType, _targetGroup, _data, _meta]];
                    _changed = true;

                    // Notify target group once
                    {
                        if (isPlayer _x) then
                        {
                            if (_purpose isEqualTo "INTEL") then
                            {
                                private _grid = mapGridPosition _destPos;
                                ["RTB Arrived: Intel Debrief", format ["Arrived at %1. Use Intel Debrief (station or ARC self-interact) to complete RTB (INTEL).", _grid], 8] remoteExec ["ARC_fnc_clientToast", _x];
                            }
                            else
                            {
                                private _grid = mapGridPosition _destPos;
                                ["RTB Arrived: EPW Processing", format ["Arrived at %1. Use Process EPW (station or ARC self-interact) to complete RTB (EPW).", _grid], 8] remoteExec ["ARC_fnc_clientToast", _x];
                            };
                        };
                    } forEach units _g;

                    private _crumb = if (_purpose isEqualTo "INTEL") then { "ORDER: %1 arrived (RTB INTEL). Awaiting debrief." } else { "ORDER: %1 arrived (RTB EPW). Awaiting processing." };
                    ["OPS", format [_crumb, _orderId], _destPos,
                        [
                            ["event", "TOC_ORDER_ARRIVED"],
                            ["orderId", _orderId],
                            ["orderType", "RTB"],
                            ["purpose", _purpose],
                            ["targetGroup", _targetGroup]
                        ]
                    ] call ARC_fnc_intelLog;
                };
            }
            else
            {
                [_taskId, "SUCCEEDED", true] call BIS_fnc_taskSetState;

                _status = "COMPLETED";
                _meta = [_meta, "completedAt", serverTime] call _setPair;

                _orders set [_i, [_orderId, _issuedAt, _status, _orderType, _targetGroup, _data, _meta]];
                _changed = true;

                ["OPS", format ["ORDER: %1 completed (RTB).", _orderId], _destPos,
                    [
                        ["event", "TOC_ORDER_COMPLETED"],
                        ["orderId", _orderId],
                        ["orderType", "RTB"],
                        ["targetGroup", _targetGroup]
                    ]
                ] call ARC_fnc_intelLog;
            };
        };
    };
};

if (_changed) then
{
    ["tocOrders", _orders] call ARC_fnc_stateSet;
    [] call ARC_fnc_intelOrderBroadcast;
    [] call ARC_fnc_publicBroadcastState;
};

_changed
