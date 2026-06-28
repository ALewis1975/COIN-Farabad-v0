/*
    Farabad UAS Screen Feed - server owner.

    Server owns only the selected feed snapshot. Clients render PiP locally from
    that snapshot; no world camera objects are persisted.
*/

if (!isServer) exitWith {false};
if (missionNamespace getVariable ["ARC_uasScreen_serverInitDone", false]) exitWith {true};
missionNamespace setVariable ["ARC_uasScreen_serverInitDone", true, true];

call compile preprocessFileLineNumbers "scripts\uasScreen\uasScreen_common.sqf";
[] call ARC_fnc_uasScreenEnsureDefaults;

if (isNil { missionNamespace getVariable "ARC_uasScreenFeedSnapshot" }) then
{
    missionNamespace setVariable ["ARC_uasScreenFeedSnapshot", [], true];
};
if (isNil { missionNamespace getVariable "ARC_uasScreenFeedSnapshotUpdatedAt" }) then
{
    missionNamespace setVariable ["ARC_uasScreenFeedSnapshotUpdatedAt", serverTime, true];
};

ARC_fnc_uasScreenPublishSnapshot = {
    private _snapshot = missionNamespace getVariable ["ARC_uasScreenFeedSnapshot", []];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };

    missionNamespace setVariable ["ARC_uasScreenFeedSnapshot", _snapshot, true];
    missionNamespace setVariable ["ARC_uasScreenFeedSnapshotUpdatedAt", serverTime, true];
    _snapshot
};

ARC_fnc_uasScreenRequestFeed = {
    if (!isServer) exitWith {false};

    params [
        ["_screenNid", "", [""]],
        ["_uavNid", "", [""]],
        ["_caller", objNull, [objNull]]
    ];

    private _remoteOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
    private _senderOk = true;
    if (!isNil "ARC_fnc_rpcValidateSender") then
    {
        _senderOk = [_caller, "ARC_fnc_uasScreenRequestFeed", "UAS screen request denied.", "UAS_SCREEN_SENDER_REJECTED", false, _remoteOwner] call ARC_fnc_rpcValidateSender;
    };
    if (!_senderOk) exitWith {false};

    if (!(missionNamespace getVariable ["ARC_uasScreenEnabled", true])) exitWith {false};

    private _screen = objectFromNetId _screenNid;
    if (isNull _screen || {!([_screen] call ARC_fnc_uasScreenIsManaged)}) exitWith
    {
        diag_log format ["[ARC][UASCREEN][WARN] rejected feed request: unmanaged screen netId=%1 caller=%2", _screenNid, name _caller];
        if ((owner _caller) > 0) then { ["Selected screen is not managed by ARC_uasScreenObjectVarNames.", "WARN", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
        false
    };

    private _uav = objectFromNetId _uavNid;
    private _validUav = false;
    {
        if (_x isEqualTo _uav) exitWith { _validUav = true; };
    } forEach ([] call ARC_fnc_uasScreenGetActiveUavs);

    if (isNull _uav || {!alive _uav} || {!_validUav}) exitWith
    {
        diag_log format ["[ARC][UASCREEN][WARN] rejected feed request: invalid UAV netId=%1 caller=%2", _uavNid, name _caller];
        if ((owner _caller) > 0) then { ["No valid active friendly UAS/UAV was selected.", "WARN", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
        false
    };

    if (missionNamespace getVariable ["ARC_uasScreenRequireAuthorizedRole", false]) then
    {
        if (isNil "ARC_fnc_rolesIsAuthorized" || {!([_caller] call ARC_fnc_rolesIsAuthorized)}) exitWith
        {
            diag_log format ["[ARC][UASCREEN][WARN] rejected feed request: unauthorized caller=%1 uid=%2", name _caller, getPlayerUID _caller];
            if ((owner _caller) > 0) then { ["You are not authorized to change UAS screen feeds.", "WARN", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
            false
        };
    };

    private _label = [_uav] call ARC_fnc_uasScreenLabel;
    private _snapshot = missionNamespace getVariable ["ARC_uasScreenFeedSnapshot", []];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };

    private _record = [_screenNid, _uavNid, serverTime, getPlayerUID _caller, name _caller, _label];
    private _idx = [_snapshot, _screenNid] call ARC_fnc_uasScreenFindRecordIndex;
    if (_idx >= 0) then { _snapshot set [_idx, _record]; } else { _snapshot pushBack _record; };

    missionNamespace setVariable ["ARC_uasScreenFeedSnapshot", _snapshot, true];
    [] call ARC_fnc_uasScreenPublishSnapshot;

    private _screenName = vehicleVarName _screen;
    if (_screenName isEqualTo "") then { _screenName = _screenNid; };

    if (!isNil "ARC_fnc_intelLog") then
    {
        ["OPS", format ["UASCREEN: %1 routed %2 to %3", name _caller, _label, _screenName], getPosATL _screen, [
            ["event", "UAS_SCREEN_FEED_SET"],
            ["screenNetId", _screenNid],
            ["uavNetId", _uavNid],
            ["uavLabel", _label],
            ["callerUid", getPlayerUID _caller]
        ]] call ARC_fnc_intelLog;
    }
    else
    {
        diag_log format ["[ARC][UASCREEN][OPS] FEED_SET screen=%1 uav=%2 caller=%3", _screenName, _label, name _caller];
    };

    if ((owner _caller) > 0) then { [format ["UAS feed routed: %1", _label], "INFO", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
    true
};

ARC_fnc_uasScreenRequestClear = {
    if (!isServer) exitWith {false};

    params [
        ["_screenNid", "", [""]],
        ["_caller", objNull, [objNull]]
    ];

    private _remoteOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
    private _senderOk = true;
    if (!isNil "ARC_fnc_rpcValidateSender") then
    {
        _senderOk = [_caller, "ARC_fnc_uasScreenRequestClear", "UAS screen clear denied.", "UAS_SCREEN_SENDER_REJECTED", false, _remoteOwner] call ARC_fnc_rpcValidateSender;
    };
    if (!_senderOk) exitWith {false};

    private _screen = objectFromNetId _screenNid;
    if (isNull _screen || {!([_screen] call ARC_fnc_uasScreenIsManaged)}) exitWith {false};

    private _snapshot = missionNamespace getVariable ["ARC_uasScreenFeedSnapshot", []];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };
    _snapshot = _snapshot select { !((_x param [0, ""]) isEqualTo _screenNid) };
    missionNamespace setVariable ["ARC_uasScreenFeedSnapshot", _snapshot, true];
    [] call ARC_fnc_uasScreenPublishSnapshot;

    private _screenName = vehicleVarName _screen;
    if (_screenName isEqualTo "") then { _screenName = _screenNid; };

    if (!isNil "ARC_fnc_intelLog") then
    {
        ["OPS", format ["UASCREEN: %1 cleared %2", name _caller, _screenName], getPosATL _screen, [
            ["event", "UAS_SCREEN_FEED_CLEAR"],
            ["screenNetId", _screenNid],
            ["callerUid", getPlayerUID _caller]
        ]] call ARC_fnc_intelLog;
    }
    else
    {
        diag_log format ["[ARC][UASCREEN][OPS] FEED_CLEAR screen=%1 caller=%2", _screenName, name _caller];
    };

    if ((owner _caller) > 0) then { [format ["UAS feed cleared: %1", _screenName], "INFO", "TOAST"] remoteExec ["ARC_fnc_clientHint", owner _caller]; };
    true
};

diag_log "[ARC][UASCREEN][INIT] server ready";
true
