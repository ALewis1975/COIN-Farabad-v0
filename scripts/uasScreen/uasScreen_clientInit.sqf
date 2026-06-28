/*
    Farabad UAS Screen Feed - client renderer/actions.

    Clients submit feed changes to the server. The server publishes a bounded
    snapshot; each client creates local PiP camera(s) from that snapshot.
*/

if (!hasInterface) exitWith {false};
if (missionNamespace getVariable ["ARC_uasScreen_clientInitDone", false]) exitWith {true};
missionNamespace setVariable ["ARC_uasScreen_clientInitDone", true, false];

call compile preprocessFileLineNumbers "scripts\uasScreen\uasScreen_common.sqf";
[] call ARC_fnc_uasScreenEnsureDefaults;

ARC_fnc_uasScreenClearFeedClient = {
    params [["_screenNid", "", [""]]];

    private _records = uiNamespace getVariable ["ARC_uasScreenLocalFeeds", []];
    if (!(_records isEqualType [])) then { _records = []; };

    private _keep = [];
    {
        if (!(_x isEqualType [])) then { continue; };
        private _sNid = _x param [0, ""];
        private _cam = _x param [2, objNull];

        if (_sNid isEqualTo _screenNid) then
        {
            if (!isNull _cam) then
            {
                _cam cameraEffect ["Terminate", "Back"];
                camDestroy _cam;
            };

            private _screen = objectFromNetId _sNid;
            if (!isNull _screen) then
            {
                private _selection = missionNamespace getVariable ["ARC_uasScreenTextureSelection", 0];
                if (!(_selection isEqualType 0)) then { _selection = 0; };
                _screen setObjectTexture [_selection, missionNamespace getVariable ["ARC_uasScreenIdleTexture", "#(argb,8,8,3)color(0,0,0,1)"]];
            };
        }
        else
        {
            _keep pushBack _x;
        };
    } forEach _records;

    uiNamespace setVariable ["ARC_uasScreenLocalFeeds", _keep];
    true
};

ARC_fnc_uasScreenApplyFeedClient = {
    params [
        ["_screenNid", "", [""]],
        ["_uavNid", "", [""]],
        ["_label", "", [""]]
    ];

    private _screen = objectFromNetId _screenNid;
    private _uav = objectFromNetId _uavNid;
    if (isNull _screen || {isNull _uav} || {!alive _uav}) exitWith {false};

    private _records = uiNamespace getVariable ["ARC_uasScreenLocalFeeds", []];
    if (!(_records isEqualType [])) then { _records = []; };

    private _same = false;
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _screenNid } && { (_x param [1, ""]) isEqualTo _uavNid }) exitWith
        {
            _same = true;
        };
    } forEach _records;
    if (_same) exitWith {true};

    [_screenNid] call ARC_fnc_uasScreenClearFeedClient;

    private _safeNid = (_screenNid splitString ":.-/ ") joinString "_";
    if (_safeNid isEqualTo "") then { _safeNid = str floor random 999999; };
    private _rt = format ["ARC_UAS_RTT_%1", _safeNid];

    private _cam = "camera" camCreate (getPosATL _uav);
    if (isNull _cam) exitWith {false};

    private _offset = missionNamespace getVariable ["ARC_uasScreenCameraOffset", [0,0,-1]];
    if (!(_offset isEqualType []) || { (count _offset) < 3 }) then { _offset = [0,0,-1]; };

    private _fov = missionNamespace getVariable ["ARC_uasScreenCameraFov", 0.55];
    if (!(_fov isEqualType 0)) then { _fov = 0.55; };
    _fov = (_fov max 0.10) min 1.20;

    _cam attachTo [_uav, _offset];
    _cam camSetFov _fov;
    _cam cameraEffect ["Internal", "Back", _rt];

    private _selection = missionNamespace getVariable ["ARC_uasScreenTextureSelection", 0];
    if (!(_selection isEqualType 0)) then { _selection = 0; };
    _screen setObjectTexture [_selection, format ["#(argb,512,512,1)r2t(%1,1)", _rt]];

    private _loop = [_screenNid, _uavNid, _cam] spawn {
        params ["_screenNid", "_uavNid", "_cam"];

        while {true} do
        {
            private _records = uiNamespace getVariable ["ARC_uasScreenLocalFeeds", []];
            if (!(_records isEqualType [])) then { _records = []; };

            private _stillWanted = false;
            {
                if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _screenNid } && { (_x param [1, ""]) isEqualTo _uavNid }) exitWith
                {
                    _stillWanted = true;
                };
            } forEach _records;
            if (!_stillWanted) exitWith {};

            private _uav = objectFromNetId _uavNid;
            if (isNull _uav || {!alive _uav} || {isNull _cam}) exitWith
            {
                [_screenNid] call ARC_fnc_uasScreenClearFeedClient;
            };

            private _mode = toUpper (missionNamespace getVariable ["ARC_uasScreenCameraMode", "NADIR"]);
            if (_mode isEqualTo "FORWARD") then
            {
                _cam setVectorDirAndUp [vectorDirVisual _uav, vectorUpVisual _uav];
            }
            else
            {
                _cam setVectorDirAndUp [[0,0,-1], [0,1,0]];
            };

            uiSleep 0.10;
        };
    };

    _records = uiNamespace getVariable ["ARC_uasScreenLocalFeeds", []];
    if (!(_records isEqualType [])) then { _records = []; };
    _records pushBack [_screenNid, _uavNid, _cam, _rt, _loop, _label];
    uiNamespace setVariable ["ARC_uasScreenLocalFeeds", _records];

    true
};

ARC_fnc_uasScreenApplySnapshotClient = {
    params [["_snapshot", missionNamespace getVariable ["ARC_uasScreenFeedSnapshot", []], [[]]]];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };

    private _wantedScreens = [];
    {
        if (!(_x isEqualType [])) then { continue; };
        private _screenNid = _x param [0, ""];
        private _uavNid = _x param [1, ""];
        private _label = _x param [5, ""];

        if (_screenNid != "" && {_uavNid != ""}) then
        {
            _wantedScreens pushBackUnique _screenNid;
            [_screenNid, _uavNid, _label] call ARC_fnc_uasScreenApplyFeedClient;
        };
    } forEach _snapshot;

    private _local = +(uiNamespace getVariable ["ARC_uasScreenLocalFeeds", []]);
    if (!(_local isEqualType [])) then { _local = []; };
    {
        if (!(_x isEqualType [])) then { continue; };
        private _screenNid = _x param [0, ""];
        if (_screenNid != "" && {!(_screenNid in _wantedScreens)}) then
        {
            [_screenNid] call ARC_fnc_uasScreenClearFeedClient;
        };
    } forEach _local;

    true
};

ARC_fnc_uasScreenSelectFeed = {
    params [
        ["_screen", objNull, [objNull]],
        ["_caller", player, [objNull]],
        ["_step", 1, [0]]
    ];

    if (isNull _screen) exitWith {false};
    private _uavs = [] call ARC_fnc_uasScreenGetActiveUavs;
    if ((count _uavs) isEqualTo 0) exitWith
    {
        ["No active friendly UAS/UAVs were found.", "WARN", "TOAST", "uas-screen-no-uav", 4] call ARC_fnc_clientHint;
        false
    };

    private _idx = _screen getVariable ["ARC_uasScreenSelectedIndex", -1];
    if (!(_idx isEqualType 0)) then { _idx = -1; };
    _idx = _idx + _step;
    if (_idx < 0) then { _idx = (count _uavs) - 1; };
    if (_idx >= (count _uavs)) then { _idx = 0; };
    _screen setVariable ["ARC_uasScreenSelectedIndex", _idx, false];

    private _uav = _uavs select _idx;
    private _label = [_uav] call ARC_fnc_uasScreenLabel;
    [netId _screen, netId _uav, _caller] remoteExecCall ["ARC_fnc_uasScreenRequestFeed", 2];
    [format ["Requesting UAS feed: %1", _label], "INFO", "TOAST", "uas-screen-select", 1] call ARC_fnc_clientHint;
    true
};

ARC_fnc_uasScreenAddActions = {
    if (!(missionNamespace getVariable ["ARC_uasScreenEnabled", true])) exitWith {false};
    [] call ARC_fnc_uasScreenEnsureDefaults;

    private _screens = [] call ARC_fnc_uasScreenResolveManagedScreens;
    private _condition = "(missionNamespace getVariable ['ARC_uasScreenEnabled', true]) && { !(missionNamespace getVariable ['ARC_uasScreenRequireAuthorizedRole', false]) || { [player] call ARC_fnc_rolesIsAuthorized } }";

    {
        private _obj = _x;
        if (isNull _obj) then { continue; };

        private _stored = _obj getVariable ["ARC_uasScreen_actionIds", []];
        if (!(_stored isEqualType [])) then { _stored = []; };

        private _needBind = true;
        if ((count _stored) > 0) then
        {
            _needBind = false;
            private _cur = actionIDs _obj;
            {
                if !(_x in _cur) exitWith { _needBind = true; };
            } forEach _stored;
        };
        if (!_needBind) then { continue; };

        { if (_x in (actionIDs _obj)) then { _obj removeAction _x; }; } forEach _stored;

        private _before = actionIDs _obj;
        _obj addAction ["[UAS] Next Active UAV Feed", { params ["_target", "_caller"]; [_target, _caller, 1] call ARC_fnc_uasScreenSelectFeed; }, [], 0.84, true, true, "", _condition, 6];
        _obj addAction ["[UAS] Previous Active UAV Feed", { params ["_target", "_caller"]; [_target, _caller, -1] call ARC_fnc_uasScreenSelectFeed; }, [], 0.83, true, true, "", _condition, 6];
        _obj addAction ["[UAS] Clear Screen Feed", { params ["_target", "_caller"]; [netId _target, _caller] remoteExecCall ["ARC_fnc_uasScreenRequestClear", 2]; }, [], 0.82, true, true, "", _condition, 6];
        _obj setVariable ["ARC_uasScreen_actionIds", (actionIDs _obj) - _before, false];
    } forEach _screens;

    true
};

[] call ARC_fnc_uasScreenAddActions;
[] call ARC_fnc_uasScreenApplySnapshotClient;

if ((missionNamespace getVariable ["ARC_uasScreenSnapshotPvEhId", -1]) < 0) then
{
    missionNamespace setVariable ["ARC_uasScreenSnapshotPvEhId", "ARC_uasScreenFeedSnapshotUpdatedAt" addPublicVariableEventHandler {
        [] call ARC_fnc_uasScreenApplySnapshotClient;
    }, false];
};

[] spawn {
    private _fastLeft = 12;
    while {true} do
    {
        uiSleep (if (_fastLeft > 0) then {5} else {45});
        if (_fastLeft > 0) then { _fastLeft = _fastLeft - 1; };
        [] call ARC_fnc_uasScreenAddActions;
        [] call ARC_fnc_uasScreenApplySnapshotClient;
    };
};

diag_log "[ARC][UASCREEN][INIT] client ready";
true
