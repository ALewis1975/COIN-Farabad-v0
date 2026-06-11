/*
    ARC_fnc_iedSpawnTick

    Phase 1 (server): Ensure the active IED objective has:
      - a deterministic device record
      - a proximity trigger that can detonate the device
      - a debug snapshot for the diary inspector

    This is intentionally conservative:
      - Only runs when an IED incident is active
      - Only applies to IED_DEVICE (not VBIED)
      - Only arms after AO activation and objective is marked armed

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _typeU = toUpper (["activeIncidentType", ""] call ARC_fnc_stateGet);
if (!(_typeU isEqualTo "IED")) exitWith {false};

private _objKind = toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet);
if (!(_objKind isEqualTo "IED_DEVICE")) exitWith {false};

private _activated = ["activeExecActivated", false] call ARC_fnc_stateGet;
if (!(_activated isEqualType true) && !(_activated isEqualType false)) then { _activated = false; };
if (!_activated) exitWith {false};

private _armed = ["activeObjectiveArmed", true] call ARC_fnc_stateGet;
if (!(_armed isEqualType true) && !(_armed isEqualType false)) then { _armed = true; };
if (!_armed) exitWith {false};

private _nid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
if (!(_nid isEqualType "")) then { _nid = ""; };
if (_nid isEqualTo "") exitWith {false};

private _obj = objectFromNetId _nid;
if (isNull _obj) exitWith {false};

private _pos = getPosATL _obj;
_pos resize 3;
_pos set [2, 0];

// Passive discovery: if a player with a mine detector is near the device,
// mark the objective discovered via the same server handler used by actions.
// This complements the client "Scan" addAction for nearby detector-equipped players.
private _passive = missionNamespace getVariable ["ARC_iedPassiveDetectEnabled", true];
if (!(_passive isEqualType true) && !(_passive isEqualType false)) then { _passive = true; };

if (_passive) then
{
    private _disc = _obj getVariable ["ARC_objectiveDiscovered", false];
    if (!(_disc isEqualType true) && !(_disc isEqualType false)) then { _disc = false; };

    if (!_disc) then
    {
        private _rad = missionNamespace getVariable ["ARC_iedPassiveDetectRadiusM", 12];
        if (!(_rad isEqualType 0) || { _rad <= 0 }) then { _rad = 12; };
        _rad = (_rad max 5) min 40;

        private _detectorFn = {
            params ["_u"];
            private _inv = items _u + assignedItems _u + weapons _u;
            ("MineDetector" in _inv) || { "ACE_VMH3" in _inv } || { "ACE_VMM3" in _inv }
        };

        private _near = allPlayers select { alive _x && { (_x distance2D _pos) <= _rad } && { [_x] call _detectorFn } };
        if ((count _near) > 0) then
        {
            private _caller = _near select 0;
            private _kindRaw = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
            if (!(_kindRaw isEqualType "")) then { _kindRaw = ""; };
            if (!(_kindRaw isEqualTo "")) then
            {
                [_kindRaw, _obj, _caller, "", "", "DISCOVER_SCAN"] call ARC_fnc_execObjectiveComplete;
            };
        };
    };
};

// Build/ensure device record
private _deviceId = ["activeIedDeviceId", ""] call ARC_fnc_stateGet;
if (!(_deviceId isEqualType "")) then { _deviceId = ""; };

private _objDevId = _obj getVariable ["ARC_ied_deviceId", ""];
if (!(_objDevId isEqualType "")) then { _objDevId = ""; };

private _needsNew = (_deviceId isEqualTo "") || { _objDevId isEqualTo "" } || { !(_objDevId isEqualTo _deviceId) };

if (_needsNew) then
{
    private _salt = floor (random 1e6);
    _deviceId = format ["IED_%1_%2", floor serverTime, _salt];

    _obj setVariable ["ARC_ied_deviceId", _deviceId, true];

    ["activeIedDeviceId", _deviceId] call ARC_fnc_stateSet;
    ["activeIedDeviceNetId", _nid] call ARC_fnc_stateSet;
    ["activeIedDeviceState", "ARMED"] call ARC_fnc_stateSet;
    ["activeIedDeviceCreatedAt", serverTime] call ARC_fnc_stateSet;

    // Record format (array):
    // [0] id (string)
    // [1] kind (string)
    // [2] netId (string)
    // [3] createdAt (number)
    // [4] posATL (array)
    // [5] triggerType (string)
    // [6] triggerRadiusM (number)
    // [7] state (string)
    // [8] metaPairs (array of [k,v])
    private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
    if (!(_zone isEqualType "")) then { _zone = ""; };
    if (_zone isEqualTo "") then { _zone = "Unzoned"; };

    private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (!(_taskId isEqualType "")) then { _taskId = ""; };

    private _meta = [
        ["taskId", _taskId],
        ["zone", _zone],
        ["grid", mapGridPosition _pos],
        ["objectiveNetId", _nid]
    ];

    private _proxRad = missionNamespace getVariable ["ARC_iedProxRadiusM", 7];
    if (!(_proxRad isEqualType 0) || { _proxRad <= 0 }) then { _proxRad = 7; };
    _proxRad = (_proxRad max 3) min 25;

    private _rec = [_deviceId, "IED_DEVICE", _nid, serverTime, _pos, "PROX_VEH", _proxRad, "ARMED", _meta];

    ["activeIedDeviceRecord", _rec] call ARC_fnc_stateSet;

    private _all = missionNamespace getVariable ["ARC_iedPhase1_deviceRecords", []];
    if (!(_all isEqualType [])) then { _all = []; };

    // Keep a compact list (tail) so debug stays cheap.
    _all pushBack _rec;
    private _cap = missionNamespace getVariable ["ARC_iedPhase1_recordsCap", 24];
    if (!(_cap isEqualType 0)) then { _cap = 24; };
    _cap = (_cap max 8) min 100;
    if ((count _all) > _cap) then { _all = _all select [(count _all) - _cap, _cap]; };

    missionNamespace setVariable ["ARC_iedPhase1_deviceRecords", _all, true];

    // Complex/chain IED reachability (once per new device): consume the
    // tier-derived execution profile from the linked threat record.
    private _threatIdCx = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
    if (!(_threatIdCx isEqualType "")) then { _threatIdCx = ""; };
    if (!(_threatIdCx isEqualTo "")) then
    {
        private _kvGetCx = {
            params ["_pairs", "_key", "_default"];
            if (!(_pairs isEqualType [])) exitWith {_default};
            private _i = -1;
            { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _i = _forEachIndex; }; } forEach _pairs;
            if (_i < 0) exitWith {_default};
            private _v = (_pairs select _i) select 1;
            if (isNil "_v") exitWith {_default};
            _v
        };

        private _recsCx = ["threat_v0_records", []] call ARC_fnc_stateGet;
        if (!(_recsCx isEqualType [])) then { _recsCx = []; };
        private _recCx = [];
        { if (([_x, "threat_id", ""] call _kvGetCx) isEqualTo _threatIdCx) exitWith { _recCx = _x; }; } forEach _recsCx;

        if ((count _recCx) > 0) then
        {
            private _execCx = [_recCx, "execution", []] call _kvGetCx;

            // Chain devices (tier >= 2 profile -> chain_count > 0)
            private _chainEnabled = missionNamespace getVariable ["ARC_iedChainEnabled", false];
            if (!(_chainEnabled isEqualType true) && !(_chainEnabled isEqualType false)) then { _chainEnabled = false; };
            private _chainCount = [_execCx, "chain_count", 0] call _kvGetCx;
            if (!(_chainCount isEqualType 0)) then { _chainCount = 0; };
            private _chainDone = _obj getVariable ["ARC_chainEmplaced", false];
            if (!(_chainDone isEqualType true) && !(_chainDone isEqualType false)) then { _chainDone = false; };
            if (_chainEnabled && { _chainCount > 0 } && { !_chainDone }) then
            {
                _obj setVariable ["ARC_chainEmplaced", true, true];
                [_nid, _chainCount] call ARC_fnc_iedChainEmplace;
            };

            // Complex attack ambush group (tier >= 3 profile -> hasSecondaryAttack)
            private _cxEnabled = missionNamespace getVariable ["ARC_iedComplexAttackEnabled", false];
            if (!(_cxEnabled isEqualType true) && !(_cxEnabled isEqualType false)) then { _cxEnabled = false; };
            private _cxStaged = missionNamespace getVariable [format ["ARC_complexAtkStaged_%1", _threatIdCx], false];
            if (!(_cxStaged isEqualType true) && !(_cxStaged isEqualType false)) then { _cxStaged = false; };
            if (_cxEnabled && { !_cxStaged }) then
            {
                missionNamespace setVariable [format ["ARC_complexAtkStaged_%1", _threatIdCx], true];
                [_recCx] call ARC_fnc_iedComplexAttackStage;
            };
        };
    };
};

// Ensure trigger exists and matches the current device id
private _trg = missionNamespace getVariable ["ARC_activeIedTrigger", objNull];
private _trgDev = missionNamespace getVariable ["ARC_activeIedTriggerDeviceId", ""];

if (!(_trgDev isEqualType "")) then { _trgDev = ""; };

private _proxRad2 = missionNamespace getVariable ["ARC_iedProxRadiusM", 7];
if (!(_proxRad2 isEqualType 0) || { _proxRad2 <= 0 }) then { _proxRad2 = 7; };
_proxRad2 = (_proxRad2 max 3) min 25;

private _needTrg = isNull _trg || { _trgDev isEqualTo "" } || { !(_trgDev isEqualTo _deviceId) };

if (_needTrg) then
{
    if (!isNull _trg) then { deleteVehicle _trg; };
    _trg = createTrigger ["EmptyDetector", _pos];
    _trg setTriggerArea [_proxRad2, _proxRad2, 0, false];
    _trg setTriggerActivation ["ANY", "PRESENT", true];

    // Only detonate on vehicles (keeps the device from popping on footstep).
    private _cond = "({(_x isKindOf 'LandVehicle') && {alive _x}} count thisList) > 0";
    _trg setVariable ["ARC_iedDeviceId", _deviceId];
    private _act = "[(thisTrigger getVariable ['ARC_iedDeviceId',''])] call ARC_fnc_iedServerDetonate;";
    _trg setTriggerStatements [_cond, _act, ""];
    missionNamespace setVariable ["ARC_activeIedTrigger", _trg];
    missionNamespace setVariable ["ARC_activeIedTriggerDeviceId", _deviceId];

    ["activeIedTriggerEnabled", true] call ARC_fnc_stateSet;
    ["activeIedTriggerRadiusM", _proxRad2] call ARC_fnc_stateSet;
};

missionNamespace setVariable ["ARC_iedPhase1_lastTickAt", serverTime, true];
// Phase 5: disposal logistics check (evidence delivery)
[] call ARC_fnc_iedServerCheckDisposal;
true
