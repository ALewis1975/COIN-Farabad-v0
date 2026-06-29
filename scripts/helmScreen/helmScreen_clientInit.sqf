/*
    Farabad Helmet-Cam / ISR-Map Screen Feed - client renderer/actions.

    Adds two groups of actions to every managed screen object:
      [HELM] Next Helmet Cam   — cycles through friendly units carrying a cTab
                                 helmet-cam item and shows their POV as PiP.
      [HELM] Previous Helmet Cam
      [HELM] Clear Screen Feed

      [MAP]  Show ISR Map View — creates a nadir PiP camera above the active
                                 AOI (ARC_activeIncidentPos or map centre).
      [MAP]  Clear Screen Feed
*/

if (!hasInterface) exitWith {false};
if (missionNamespace getVariable ["ARC_helmScreen_clientInitDone", false]) exitWith {true};
missionNamespace setVariable ["ARC_helmScreen_clientInitDone", true, false];

call compile preprocessFileLineNumbers "scripts\helmScreen\helmScreen_common.sqf";
[] call ARC_fnc_helmScreenEnsureDefaults;

// ---------------------------------------------------------------------------
// Low-level PiP camera management (uiNamespace)
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenClearFeedClient = {
    params [["_screenNid", "", [""]]];

    private _records = uiNamespace getVariable ["ARC_helmScreenLocalFeeds", []];
    if (!(_records isEqualType [])) then { _records = []; };

    private _keep = [];
    {
        if (!(_x isEqualType [])) then { continue; };
        private _sNid = _x param [0, ""];
        private _cam  = _x param [2, objNull];

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
                private _sel = missionNamespace getVariable ["ARC_helmScreenTextureSelection", 0];
                if (!(_sel isEqualType 0)) then { _sel = 0; };
                _screen setObjectTexture [_sel, missionNamespace getVariable ["ARC_helmScreenIdleTexture", "#(argb,8,8,3)color(0,0,0,1)"]];
            };
        }
        else
        {
            _keep pushBack _x;
        };
    } forEach _records;

    uiNamespace setVariable ["ARC_helmScreenLocalFeeds", _keep];
    true
};

// Attach a PiP camera to _source (a unit) and display on _screen.
// feedType: "HELM" or "MAP"
ARC_fnc_helmScreenApplyFeedClient = {
    params [
        ["_screenNid", "", [""]],
        ["_sourceNid", "", [""]],
        ["_feedType", "HELM", [""]],
        ["_label", "", [""]]
    ];

    _feedType = toUpper _feedType;

    private _screen = objectFromNetId _screenNid;
    if (isNull _screen) exitWith {false};

    // For MAP mode _source can be objNull; that's fine — we create a free camera.
    private _source = objectFromNetId _sourceNid;

    // Dedup: skip if the exact same feed is already playing
    private _records = uiNamespace getVariable ["ARC_helmScreenLocalFeeds", []];
    if (!(_records isEqualType [])) then { _records = []; };

    private _same = false;
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _screenNid } && { (_x param [1, ""]) isEqualTo _sourceNid } && { (toUpper (_x param [3, ""])) isEqualTo _feedType }) exitWith
        {
            _same = true;
        };
    } forEach _records;
    if (_same) exitWith {true};

    [_screenNid] call ARC_fnc_helmScreenClearFeedClient;

    private _safeNid = (_screenNid splitString ":.-/ ") joinString "_";
    if (_safeNid isEqualTo "") then { _safeNid = str floor random 999999; };
    private _rt = format ["ARC_HELM_RTT_%1", _safeNid];

    private _fov = missionNamespace getVariable ["ARC_helmScreenCameraFov", 0.70];
    if (!(_fov isEqualType 0)) then { _fov = 0.70; };
    _fov = (_fov max 0.10) min 1.20;

    private _sel = missionNamespace getVariable ["ARC_helmScreenTextureSelection", 0];
    if (!(_sel isEqualType 0)) then { _sel = 0; };

    private _cam = objNull;

    if (_feedType isEqualTo "HELM") then
    {
        if (isNull _source || {!alive _source}) exitWith {false};

        private _offset = missionNamespace getVariable ["ARC_helmScreenCameraOffset", [0, 0, 0.15]];
        if (!(_offset isEqualType []) || { (count _offset) < 3 }) then { _offset = [0, 0, 0.15]; };

        _cam = "camera" camCreate (getPosATL _source);
        if (isNull _cam) exitWith {false};

        _cam attachTo [_source, _offset];
        _cam camSetFov _fov;
        _cam cameraEffect ["Internal", "Back", _rt];
    };

    if (_feedType isEqualTo "MAP") then
    {
        private _altM = missionNamespace getVariable ["ARC_helmScreenMapAltM", 350];
        if (!(_altM isEqualType 0)) then { _altM = 350; };
        _altM = (_altM max 50) min 3000;

        private _mapFov = missionNamespace getVariable ["ARC_helmScreenMapFov", 0.65];
        if (!(_mapFov isEqualType 0)) then { _mapFov = 0.65; };
        _mapFov = (_mapFov max 0.10) min 1.20;

        // Prefer active incident centre; fall back to worldSize midpoint
        private _aoi = missionNamespace getVariable ["ARC_activeIncidentPos", []];
        if (!(_aoi isEqualType []) || { (count _aoi) < 2 }) then
        {
            private _half = worldSize / 2;
            _aoi = [_half, _half, 0];
        };
        private _aoiPos = [_aoi select 0, _aoi select 1, _altM];

        _cam = "camera" camCreate _aoiPos;
        if (isNull _cam) exitWith {false};

        _cam camSetFov _mapFov;
        _cam setVectorDirAndUp [[0,0,-1], [0,1,0]];  // nadir / straight-down
        _cam cameraEffect ["Internal", "Back", _rt];
    };

    if (isNull _cam) exitWith {false};

    _screen setObjectTexture [_sel, format ["#(argb,512,512,1)r2t(%1,1)", _rt]];

    private _loop = [_screenNid, _sourceNid, _cam, _feedType] spawn {
        params ["_screenNid", "_sourceNid", "_cam", "_feedType"];
        _feedType = toUpper _feedType;

        while {true} do
        {
            private _records = uiNamespace getVariable ["ARC_helmScreenLocalFeeds", []];
            if (!(_records isEqualType [])) then { _records = []; };

            private _stillWanted = false;
            {
                if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _screenNid } && { (_x param [1, ""]) isEqualTo _sourceNid }) exitWith
                {
                    _stillWanted = true;
                };
            } forEach _records;
            if (!_stillWanted) exitWith {};

            if (isNull _cam) exitWith { [_screenNid] call ARC_fnc_helmScreenClearFeedClient; };

            if (_feedType isEqualTo "HELM") then
            {
                private _unit = objectFromNetId _sourceNid;
                if (isNull _unit || {!alive _unit}) exitWith
                {
                    [_screenNid] call ARC_fnc_helmScreenClearFeedClient;
                };

                // Keep camera pointed in the direction the unit is facing
                _cam setVectorDirAndUp [vectorDir _unit, vectorUp _unit];
            };
            // MAP camera is static-nadir; no per-frame direction update needed.

            uiSleep 0.10;
        };
    };

    _records = uiNamespace getVariable ["ARC_helmScreenLocalFeeds", []];
    if (!(_records isEqualType [])) then { _records = []; };
    // record: [screenNid, sourceNid, cam, feedType, rt, loop, label]
    _records pushBack [_screenNid, _sourceNid, _cam, _feedType, _rt, _loop, _label];
    uiNamespace setVariable ["ARC_helmScreenLocalFeeds", _records];

    true
};

ARC_fnc_helmScreenApplySnapshotClient = {
    params [["_snapshot", missionNamespace getVariable ["ARC_helmScreenFeedSnapshot", []], [[]]]];
    if (!(_snapshot isEqualType [])) then { _snapshot = []; };

    private _wantedScreens = [];
    {
        if (!(_x isEqualType [])) then { continue; };
        private _screenNid = _x param [0, ""];
        private _sourceNid = _x param [1, ""];
        private _feedType  = toUpper (_x param [2, "HELM"]);
        private _label     = _x param [6, ""];

        if (_screenNid != "") then
        {
            _wantedScreens pushBackUnique _screenNid;
            [_screenNid, _sourceNid, _feedType, _label] call ARC_fnc_helmScreenApplyFeedClient;
        };
    } forEach _snapshot;

    private _local = +(uiNamespace getVariable ["ARC_helmScreenLocalFeeds", []]);
    if (!(_local isEqualType [])) then { _local = []; };
    {
        if (!(_x isEqualType [])) then { continue; };
        private _screenNid = _x param [0, ""];
        if (_screenNid != "" && {!(_screenNid in _wantedScreens)}) then
        {
            [_screenNid] call ARC_fnc_helmScreenClearFeedClient;
        };
    } forEach _local;

    true
};

// ---------------------------------------------------------------------------
// Helmet-cam cycling — mirrors ARC_fnc_uasScreenSelectFeed
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenSelectFeed = {
    params [
        ["_screen", objNull, [objNull]],
        ["_caller", player, [objNull]],
        ["_step", 1, [0]]
    ];

    if (isNull _screen) exitWith {false};
    private _units = [] call ARC_fnc_helmScreenGetHelmCamUnits;
    if ((count _units) isEqualTo 0) exitWith
    {
        ["No friendly units with a helmet cam were found.", "WARN", "TOAST", "helm-screen-no-unit", 4] call ARC_fnc_clientHint;
        false
    };

    private _idx = _screen getVariable ["ARC_helmScreenSelectedIndex", -1];
    if (!(_idx isEqualType 0)) then { _idx = -1; };
    _idx = _idx + _step;
    if (_idx < 0) then { _idx = (count _units) - 1; };
    if (_idx >= (count _units)) then { _idx = 0; };
    _screen setVariable ["ARC_helmScreenSelectedIndex", _idx, false];

    private _unit = _units select _idx;
    private _label = [_unit] call ARC_fnc_helmScreenUnitLabel;
    [netId _screen, netId _unit, "HELM", _caller] remoteExecCall ["ARC_fnc_helmScreenRequestFeed", 2];
    [format ["Requesting helmet cam: %1", _label], "INFO", "TOAST", "helm-screen-select", 1] call ARC_fnc_clientHint;
    [_screen] call ARC_fnc_helmScreenRefreshActionTitles;
    true
};

// ---------------------------------------------------------------------------
// Dynamic action-title refresh for helmet-cam Next/Previous buttons
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenRefreshActionTitles = {
    params [["_screen", objNull, [objNull]]];
    if (isNull _screen) exitWith {};

    private _nextId = _screen getVariable ["ARC_helmScreen_nextActionId", -1];
    private _prevId = _screen getVariable ["ARC_helmScreen_prevActionId", -1];
    if (!(_nextId isEqualType 0)) then { _nextId = -1; };
    if (!(_prevId isEqualType 0)) then { _prevId = -1; };
    if (_nextId < 0 && { _prevId < 0 }) exitWith {};

    private _units = [] call ARC_fnc_helmScreenGetHelmCamUnits;
    private _count = count _units;
    if (_count isEqualTo 0) exitWith
    {
        if (_nextId >= 0) then { _screen setUserActionText [_nextId, "[HELM] Next Helmet Cam"]; };
        if (_prevId >= 0) then { _screen setUserActionText [_prevId, "[HELM] Previous Helmet Cam"]; };
    };

    private _curIdx = _screen getVariable ["ARC_helmScreenSelectedIndex", -1];
    if (!(_curIdx isEqualType 0)) then { _curIdx = -1; };

    private _nextIdx = (_curIdx + 1);
    if (_nextIdx < 0) then { _nextIdx = _count - 1; };
    if (_nextIdx >= _count) then { _nextIdx = 0; };

    private _prevIdx = (_curIdx - 1);
    if (_prevIdx < 0) then { _prevIdx = _count - 1; };
    if (_prevIdx >= _count) then { _prevIdx = 0; };

    private _nextLabel = [_units select _nextIdx] call ARC_fnc_helmScreenUnitShortLabel;
    private _prevLabel = [_units select _prevIdx] call ARC_fnc_helmScreenUnitShortLabel;

    if (_nextId >= 0) then { _screen setUserActionText [_nextId, format ["[HELM] Next: %1", _nextLabel]]; };
    if (_prevId >= 0) then { _screen setUserActionText [_prevId, format ["[HELM] Prev: %1", _prevLabel]]; };
};

// ---------------------------------------------------------------------------
// Action binding — adds HELM and MAP action groups to every managed screen
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenAddActions = {
    if (!(missionNamespace getVariable ["ARC_helmScreenEnabled", true])) exitWith {false};
    [] call ARC_fnc_helmScreenEnsureDefaults;

    private _screens = [] call ARC_fnc_helmScreenResolveManagedScreens;
    private _condition = "(missionNamespace getVariable ['ARC_helmScreenEnabled', true]) && { !(missionNamespace getVariable ['ARC_helmScreenRequireAuthorizedRole', false]) || { !(isNil 'ARC_fnc_rolesIsAuthorized') && { [player] call ARC_fnc_rolesIsAuthorized } } }";

    {
        private _obj = _x;
        if (isNull _obj) then { continue; };

        private _stored = _obj getVariable ["ARC_helmScreen_actionIds", []];
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

        // HELM group
        private _nextId = _obj addAction ["[HELM] Next Helmet Cam",     { params ["_target", "_caller"]; [_target, _caller,  1] call ARC_fnc_helmScreenSelectFeed; }, [], 0.80, true, true, "", _condition, 6];
        private _prevId = _obj addAction ["[HELM] Previous Helmet Cam", { params ["_target", "_caller"]; [_target, _caller, -1] call ARC_fnc_helmScreenSelectFeed; }, [], 0.79, true, true, "", _condition, 6];
        private _helmClearId = _obj addAction ["[HELM] Clear Screen Feed", { params ["_target", "_caller"]; [netId _target, _caller] remoteExecCall ["ARC_fnc_helmScreenRequestClear", 2]; }, [], 0.78, true, true, "", _condition, 6];

        // MAP group
        private _mapId  = _obj addAction ["[MAP]  Show ISR Map View", { params ["_target", "_caller"]; [netId _target, "", "MAP", _caller] remoteExecCall ["ARC_fnc_helmScreenRequestFeed", 2]; [format ["Requesting ISR map view for %1", vehicleVarName _target], "INFO", "TOAST", "helm-screen-map", 1] call ARC_fnc_clientHint; }, [], 0.77, true, true, "", _condition, 6];
        private _mapClearId = _obj addAction ["[MAP]  Clear ISR Map View", { params ["_target", "_caller"]; [netId _target, _caller] remoteExecCall ["ARC_fnc_helmScreenRequestClear", 2]; }, [], 0.76, true, true, "", _condition, 6];

        _obj setVariable ["ARC_helmScreen_nextActionId", _nextId, false];
        _obj setVariable ["ARC_helmScreen_prevActionId", _prevId, false];
        _obj setVariable ["ARC_helmScreen_actionIds", [_nextId, _prevId, _helmClearId, _mapId, _mapClearId], false];
        [_obj] call ARC_fnc_helmScreenRefreshActionTitles;
    } forEach _screens;

    true
};

[] call ARC_fnc_helmScreenAddActions;
[] call ARC_fnc_helmScreenApplySnapshotClient;

if ((missionNamespace getVariable ["ARC_helmScreenSnapshotPvEhId", -1]) < 0) then
{
    missionNamespace setVariable ["ARC_helmScreenSnapshotPvEhId", "ARC_helmScreenFeedSnapshotUpdatedAt" addPublicVariableEventHandler {
        [] call ARC_fnc_helmScreenApplySnapshotClient;
    }, false];
};

[] spawn {
    private _fastLeft = 12;
    while {true} do
    {
        uiSleep (if (_fastLeft > 0) then {5} else {45});
        if (_fastLeft > 0) then { _fastLeft = _fastLeft - 1; };
        [] call ARC_fnc_helmScreenAddActions;
        [] call ARC_fnc_helmScreenApplySnapshotClient;
    };
};

diag_log "[ARC][HELMSCREEN][INIT] client ready";
true
