/*
    Farabad Helmet-Cam / ISR-Map Screen Feed - server owner.

    Server owns only the active feed snapshot.  Clients render PiP locally;
    no world camera objects are persisted on the server.
*/

if (!isServer) exitWith {false};
if (missionNamespace getVariable ["ARC_helmScreen_serverInitDone", false]) exitWith {true};
missionNamespace setVariable ["ARC_helmScreen_serverInitDone", true, true];

call compile preprocessFileLineNumbers "scripts\helmScreen\helmScreen_common.sqf";
[] call ARC_fnc_helmScreenEnsureDefaults;

if (isNil { missionNamespace getVariable "ARC_helmScreenFeedSnapshot" }) then
{
    missionNamespace setVariable ["ARC_helmScreenFeedSnapshot", [], true];
};
if (isNil { missionNamespace getVariable "ARC_helmScreenFeedSnapshotUpdatedAt" }) then
{
    missionNamespace setVariable ["ARC_helmScreenFeedSnapshotUpdatedAt", serverTime, true];
};

ARC_fnc_helmScreenPublishSnapshot = {
    private _snapshot = missionNamespace getVariable ["ARC_helmScreenFeedSnapshot", []];
    if (!(_snapshot isEqualType [])) then
    {
        _snapshot = [];
        missionNamespace setVariable ["ARC_helmScreenFeedSnapshot", _snapshot, true];
    };

    missionNamespace setVariable ["ARC_helmScreenFeedSnapshotUpdatedAt", serverTime, true];
    _snapshot
};

// ---------------------------------------------------------------------------
// RPC: set a helmet-cam or MAP feed on a managed screen
//
// Params: [_screenNid, _sourceNid, _feedType, _caller]
//   _feedType: "HELM" or "MAP"
//   _sourceNid: netId of the unit (HELM) or "" (MAP)
// ---------------------------------------------------------------------------
ARC_fnc_helmScreenRequestFeed = {
    if (!isServer) exitWith {false};

    params [
        ["_screenNid", "", [""]],
        ["_sourceNid", "", [""]],
        ["_feedType",  "HELM", [""]],
        ["_caller", objNull, [objNull]]
    ];

    if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
    private _remoteOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
    if (!([_caller, "ARC_fnc_helmScreenRequestFeed", "Helm screen request denied.", "HELM_SCREEN_SENDER_REJECTED", true, _remoteOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};

    if (!(missionNamespace getVariable ["ARC_helmScreenEnabled", true])) exitWith {false};

    private _screen = objectFromNetId _screenNid;
    if (isNull _screen || {!([_screen] call ARC_fnc_helmScreenIsManaged)}) exitWith
    {
        diag_log format ["[ARC][HELMSCREEN][WARN] rejected request: unmanaged screen netId=%1 caller=%2", _screenNid, name _caller];
        if ((owner _caller) > 0) then { ["Selected screen is not managed.", "WARN", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
        false
    };

    _feedType = toUpper _feedType;
    if (!(_feedType in ["HELM", "MAP"])) exitWith
    {
        diag_log format ["[ARC][HELMSCREEN][WARN] unknown feedType=%1 caller=%2", _feedType, name _caller];
        false
    };

    if (missionNamespace getVariable ["ARC_helmScreenRequireAuthorizedRole", false]) then
    {
        if (isNil "ARC_fnc_rolesIsAuthorized" || {!([_caller] call ARC_fnc_rolesIsAuthorized)}) exitWith
        {
            diag_log format ["[ARC][HELMSCREEN][WARN] unauthorized caller=%1 uid=%2", name _caller, getPlayerUID _caller];
            if ((owner _caller) > 0) then { ["You are not authorized to change screen feeds.", "WARN", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
            false
        };
    };

    private _label = "";
    if (_feedType isEqualTo "HELM") then
    {
        private _unit = objectFromNetId _sourceNid;
        private _validUnit = false;
        {
            if (_x isEqualTo _unit) exitWith { _validUnit = true; };
        } forEach ([] call ARC_fnc_helmScreenGetHelmCamUnits);

        if (isNull _unit || {!alive _unit} || {!_validUnit}) exitWith
        {
            diag_log format ["[ARC][HELMSCREEN][WARN] invalid unit netId=%1 caller=%2", _sourceNid, name _caller];
            if ((owner _caller) > 0) then { ["No valid helmet-cam unit found.", "WARN", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
            false
        };

        _label = [_unit] call ARC_fnc_helmScreenUnitLabel;
    }
    else
    {
        // MAP: source is empty; label notes the AOI
        _label = "ISR MAP (overhead)";
    };

    private _snapshot = missionNamespace getVariable ["ARC_helmScreenFeedSnapshot", []];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };

    // record: [screenNid, sourceNid, feedType, serverTime, callerUID, callerName, label]
    private _record = [_screenNid, _sourceNid, _feedType, serverTime, getPlayerUID _caller, name _caller, _label];
    private _idx = [_snapshot, _screenNid] call ARC_fnc_helmScreenFindRecordIndex;
    if (_idx >= 0) then { _snapshot set [_idx, _record]; } else { _snapshot pushBack _record; };

    missionNamespace setVariable ["ARC_helmScreenFeedSnapshot", _snapshot, true];
    [] call ARC_fnc_helmScreenPublishSnapshot;

    private _screenName = vehicleVarName _screen;
    if (_screenName isEqualTo "") then { _screenName = _screenNid; };

    if (!isNil "ARC_fnc_intelLog") then
    {
        ["OPS", format ["HELMSCREEN: %1 routed %2 to %3", name _caller, _label, _screenName], getPosATL _screen, [
            ["event", "HELM_SCREEN_FEED_SET"],
            ["screenNetId", _screenNid],
            ["sourceNetId", _sourceNid],
            ["feedType", _feedType],
            ["label", _label],
            ["callerUid", getPlayerUID _caller]
        ]] call ARC_fnc_intelLog;
    }
    else
    {
        diag_log format ["[ARC][HELMSCREEN][OPS] FEED_SET screen=%1 type=%2 source=%3 caller=%4", _screenName, _feedType, _label, name _caller];
    };

    if ((owner _caller) > 0) then { [format ["Screen feed routed: %1", _label], "INFO", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
    true
};

// ---------------------------------------------------------------------------
// RPC: clear a managed screen's helm/map feed
// ---------------------------------------------------------------------------
ARC_fnc_helmScreenRequestClear = {
    if (!isServer) exitWith {false};

    params [
        ["_screenNid", "", [""]],
        ["_caller", objNull, [objNull]]
    ];

    if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
    private _remoteOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
    if (!([_caller, "ARC_fnc_helmScreenRequestClear", "Helm screen clear denied.", "HELM_SCREEN_SENDER_REJECTED", true, _remoteOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};

    private _screen = objectFromNetId _screenNid;
    if (isNull _screen || {!([_screen] call ARC_fnc_helmScreenIsManaged)}) exitWith {false};

    private _snapshot = missionNamespace getVariable ["ARC_helmScreenFeedSnapshot", []];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };
    _snapshot = _snapshot select { !((_x param [0, ""]) isEqualTo _screenNid) };
    missionNamespace setVariable ["ARC_helmScreenFeedSnapshot", _snapshot, true];
    [] call ARC_fnc_helmScreenPublishSnapshot;

    private _screenName = vehicleVarName _screen;
    if (_screenName isEqualTo "") then { _screenName = _screenNid; };

    if (!isNil "ARC_fnc_intelLog") then
    {
        ["OPS", format ["HELMSCREEN: %1 cleared %2", name _caller, _screenName], getPosATL _screen, [
            ["event", "HELM_SCREEN_FEED_CLEAR"],
            ["screenNetId", _screenNid],
            ["callerUid", getPlayerUID _caller]
        ]] call ARC_fnc_intelLog;
    }
    else
    {
        diag_log format ["[ARC][HELMSCREEN][OPS] FEED_CLEAR screen=%1 caller=%2", _screenName, name _caller];
    };

    if ((owner _caller) > 0) then { [format ["Screen feed cleared: %1", _screenName], "INFO", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
    true
};

diag_log "[ARC][HELMSCREEN][INIT] server ready";
true
