/*
    Server RPC: cancel a queued flight ID.
    Params: [OBJECT caller, STRING flightId]
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";
private _findIfFn   = compile "params ['_arr','_cond']; private _r = -1; { if (_x call _cond) exitWith { _r = _forEachIndex; }; } forEach _arr; _r";

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };
if (isNil "ARC_fnc_airbaseRestoreParkedAsset") then { ARC_fnc_airbaseRestoreParkedAsset = compile preprocessFileLineNumbers "functions\\ambiance\\fn_airbaseRestoreParkedAsset.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_flightId", "", [""]]
];

if (!([_caller, "ARC_fnc_airbaseRequestCancelQueuedFlight", "Airbase cancel request rejected: sender verification failed.", "AIRBASE_CANCEL_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _auth = [_caller, "CANCEL"] call ARC_fnc_airbaseTowerAuthorize;
_auth params ["_ok", "_level", "_reason"];
if (!_ok) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Airbase cancel request denied: tower authorization required."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CONTROL DENIED: CANCEL by %1 (%2)", name _caller, _reason], getPosATL _caller, 0, [
        ["event", "AIRBASE_CANCEL_AUTH_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["level", _level],
        ["reason", _reason],
        ["flightId", _flightId]
    ]] call ARC_fnc_intelLog;
    false
};

if (!(_flightId isEqualType "")) then { _flightId = ""; };
_flightId = [_flightId] call _trimFn;
if (_flightId isEqualTo "") exitWith {false};

private _queue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType [])) then { _queue = []; };

private _idx = -1;
{ if (((_x param [0, ""]) isEqualTo _flightId)) exitWith { _idx = _forEachIndex; }; } forEach _queue;
if (_idx < 0) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { [format ["Flight %1 is not currently queued.", _flightId]] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _recs = ["airbase_v1_records", []] call ARC_fnc_stateGet;
if (!(_recs isEqualType [])) then { _recs = []; };
private _rIdx = -1;
{ if (((_x param [0, ""]) isEqualTo _flightId)) exitWith { _rIdx = _forEachIndex; }; } forEach _recs;

// Prevent cancellation of currently executing flights.
private _execFid = missionNamespace getVariable ["airbase_v1_execFid", ""];
if (_execFid isEqualTo _flightId) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { [format ["Flight %1 is currently executing and cannot be canceled.", _flightId]] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CONTROL DENIED: cancel blocked for active flight %1", _flightId], getPosATL _caller, 0, [
        ["event", "AIRBASE_CANCEL_ACTIVE_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["authLevel", _level],
        ["flightId", _flightId]
    ]] call ARC_fnc_intelLog;
    false
};

if (_rIdx >= 0) then {
    private _status = (_recs select _rIdx) param [5, ""];
    if (_status isEqualTo "ACTIVE") exitWith {
        private _owner = owner _caller;
        if (_owner > 0) then { [format ["Flight %1 is currently executing and cannot be canceled.", _flightId]] remoteExec ["ARC_fnc_clientHint", _owner]; };

        ["OPS", format ["AIRBASE CONTROL DENIED: cancel blocked for ACTIVE record %1", _flightId], getPosATL _caller, 0, [
            ["event", "AIRBASE_CANCEL_ACTIVE_RECORD_DENIED"],
            ["caller", name _caller],
            ["uid", getPlayerUID _caller],
            ["authLevel", _level],
            ["flightId", _flightId]
        ]] call ARC_fnc_intelLog;
        false
    };
};

private _qItem = _queue select _idx;
private _qKind = _qItem param [1, ""];
private _qDetail = _qItem param [2, ""];

// RETURN arrivals leave their source asset in RETURN_QUEUED; restore asset state before reporting success.
if (_qKind isEqualTo "ARR" && { _qDetail isEqualType "" && { !(_qDetail isEqualTo "INBOUND") } }) then {
    private _isReturn = false;

    if (_rIdx >= 0) then {
        private _rec = _recs select _rIdx;
        private _meta = _rec param [7, []];
        if (_meta isEqualType []) then {
            private _modeIdx = -1;
            { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo "mode" } && { (_x select 1) isEqualTo "RETURN" }) exitWith { _modeIdx = _forEachIndex; }; } forEach _meta;
            _isReturn = (_modeIdx >= 0);
        };
    };

    if (_isReturn) then {
        private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
        private _assets = [];
        if (_rt isEqualType createHashMap) then {
            _assets = _rt get "assets";
            if (isNil "_assets" || {!(_assets isEqualType [])}) then { _assets = []; };
        };

        private _aIdx = [_assets, {
            private _assetId = "";
            if (_x isEqualType createHashMap) then {
                _assetId = _x get "id";
                if (isNil "_assetId" || {!(_assetId isEqualType "")}) then { _assetId = ""; };
            };
            _assetId isEqualTo _qDetail
        }] call _findIfFn;

        if (_aIdx < 0) exitWith {
            private _owner = owner _caller;
            if (_owner > 0) then { [format ["Flight %1 could not be canceled safely (return asset missing).", _flightId]] remoteExec ["ARC_fnc_clientHint", _owner]; };

            ["OPS", format ["AIRBASE CONTROL DENIED: cancel aborted for RETURN flight %1 (asset missing)", _flightId], getPosATL _caller, 0, [
                ["event", "AIRBASE_CANCEL_RETURN_ASSET_MISSING"],
                ["caller", name _caller],
                ["uid", getPlayerUID _caller],
                ["authLevel", _level],
                ["flightId", _flightId],
                ["assetId", _qDetail]
            ]] call ARC_fnc_intelLog;
            false
        };

        private _asset = _assets select _aIdx;
        private _okRestore = [_asset] call ARC_fnc_airbaseRestoreParkedAsset;
        if (!_okRestore) exitWith {
            private _owner = owner _caller;
            if (_owner > 0) then { [format ["Flight %1 could not be canceled safely (return asset restore failed).", _flightId]] remoteExec ["ARC_fnc_clientHint", _owner]; };

            ["OPS", format ["AIRBASE CONTROL DENIED: cancel aborted for RETURN flight %1 (restore failed)", _flightId], getPosATL _caller, 0, [
                ["event", "AIRBASE_CANCEL_RETURN_RESTORE_FAILED"],
                ["caller", name _caller],
                ["uid", getPlayerUID _caller],
                ["authLevel", _level],
                ["flightId", _flightId],
                ["assetId", _qDetail]
            ]] call ARC_fnc_intelLog;
            false
        };
    };
};

_queue deleteAt _idx;
["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
if (_rIdx >= 0) then {
    private _r = _recs select _rIdx;
    _r set [5, "CANCELLED"];
    _r set [6, serverTime];
    private _meta = _r param [7, []];
    if (!(_meta isEqualType [])) then { _meta = []; };
    _meta pushBack ["cancelledBy", name _caller];
    _meta pushBack ["cancelledByUid", getPlayerUID _caller];
    _r set [7, _meta];
    _recs set [_rIdx, _r];
    ["airbase_v1_records", _recs] call ARC_fnc_stateSet;
};

private _manualPriority = ["airbase_v1_manualPriority", []] call ARC_fnc_stateGet;
if (!(_manualPriority isEqualType [])) then { _manualPriority = []; };
_manualPriority = _manualPriority select { _x isEqualType "" && { !(_x isEqualTo _flightId) } };
["airbase_v1_manualPriority", _manualPriority] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CONTROL: cancelled flight %1 by %2", _flightId, name _caller], getPosATL _caller, 0, [
    ["event", "AIRBASE_QUEUE_CANCEL"],
    ["caller", name _caller],
    ["uid", getPlayerUID _caller],
    ["authLevel", _level],
    ["flightId", _flightId],
    ["queueLen", count _queue]
]] call ARC_fnc_intelLog;

true
