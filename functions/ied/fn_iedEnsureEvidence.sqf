/*
    ARC_fnc_iedEnsureEvidence

    Phase 2 (server): Ensure an evidence prop exists for the currently active IED incident.

    This is a gameplay abstraction. The “evidence” object is a collectible prop that
    drives TECHINT logging and an optional follow-on lead.

    Params:
        0: ARRAY  - posATL (best effort; optional)
        1: STRING - cause tag (DISCOVER | DISCOVER_SCAN | POST_BLAST | MANUAL)

    Returns:
        BOOL
*/
if (!isServer) exitWith {false};

params [
    ["_posATL", [], [[]]],
    ["_cause", "DISCOVER", [""]]
];

private _incType = toUpper (["activeIncidentType", ""] call ARC_fnc_stateGet);
if (!(_incType isEqualTo "IED")) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_taskId isEqualType "") || { _taskId isEqualTo "" }) exitWith {false};

private _existingNid = ["activeIedEvidenceNetId", ""] call ARC_fnc_stateGet;
if (!(_existingNid isEqualType "")) then { _existingNid = ""; };

if (!(_existingNid isEqualTo "")) then
{
    private _ex = objectFromNetId _existingNid;
    if (!isNull _ex) exitWith {true};
    // Stale netId (object cleaned/despawned) – clear and recreate
    ["activeIedEvidenceNetId", ""] call ARC_fnc_stateSet;
};

private _p = _posATL;
if (!(_p isEqualType []) || { (count _p) < 2 }) then
{
    _p = ["activeIedDetonationPos", []] call ARC_fnc_stateGet;
    if (!(_p isEqualType []) || { (count _p) < 2 }) then
    {
        _p = ["activeObjectivePos", []] call ARC_fnc_stateGet;
    };
};
if (!(_p isEqualType []) || { (count _p) < 2 }) exitWith {false};
_p = +_p; _p resize 3;

private _radius = missionNamespace getVariable ["ARC_iedEvidenceSpawnRadiusM", 6];
if (!(_radius isEqualType 0) || { _radius <= 0 }) then { _radius = 6; };
_radius = (_radius max 2) min 20;

// Requirement: IED evidence must spawn on/very near a road and outside buildings.
private _roadRad = missionNamespace getVariable ["ARC_iedEvidenceRoadSearchRadiusM", 45];
if (!(_roadRad isEqualType 0) || { _roadRad <= 0 }) then { _roadRad = 45; };
_roadRad = (_roadRad max 15) min 200;

private _posE = _p;
private _roads = _p nearRoads _roadRad;
private _placed = false;

if (_roads isEqualType [] && { (count _roads) > 0 }) then
{
    for "_i" from 0 to 20 do
    {
        private _r = selectRandom _roads;
        if (isNull _r) then { continue; };

        private _rp = getPosATL _r;
        _rp = +_rp; _rp resize 3;

        private _dir = getDir _r;
        if (!(_dir isEqualType 0)) then { _dir = random 360; };

        private _side = if (random 1 < 0.5) then { -1 } else { 1 };
        private _off = 0.4 + random 1.0; // stay close to road
        private _fwd = -1.5 + random 3.0;

        private _cand = _rp getPos [_fwd, _dir];
        _cand = _cand getPos [_side * _off, _dir + 90];
        _cand = +_cand; _cand resize 3;

        if (surfaceIsWater _cand) then { continue; };
        private _b = nearestBuilding _cand;
        if (!isNull _b && { (_cand distance2D _b) < 8 }) then { continue; };

        _posE = _cand;
        _placed = true;
        break;
    };
};

// Roadless fallback (should be rare): random around the device.
if (!_placed) then
{
    for "_i" from 0 to 15 do
    {
        private _cand = [
            (_p # 0) + (random (_radius * 2) - _radius),
            (_p # 1) + (random (_radius * 2) - _radius),
            (_p # 2)
        ];
        if (surfaceIsWater _cand) then { continue; };
        private _b = nearestBuilding _cand;
        if (!isNull _b && { (_cand distance2D _b) < 8 }) then { continue; };
        _posE = _cand;
        break;
    };
};

private _cls = missionNamespace getVariable ["ARC_iedEvidenceClass", "Land_File1_F"];
if (!(_cls isEqualType "")) then { _cls = "Land_File1_F"; };

private _obj = createVehicle [_cls, _posE, [], 0, "CAN_COLLIDE"];
if (isNull _obj) exitWith {false};
// Keep evidence on the selected ATL surface near the device; do NOT snap upward (prevents rooftop spawns).
private _pz = _posE # 2; if (!(_pz isEqualType 0)) then { _pz = 0; };
_obj setPosATL [_posE # 0, _posE # 1, _pz + 0.05];
_obj setVectorUp [0,0,1];
_obj allowDamage false;

_obj setVariable ["ARC_isIedEvidence", true, true];
_obj setVariable ["ARC_iedEvidenceTaskId", _taskId, true];
_obj setVariable ["ARC_iedEvidenceCause", toUpper _cause, true];
_obj setVariable ["ARC_iedEvidenceCreatedAt", serverTime, true];

private _nid = netId _obj;
["activeIedEvidenceNetId", _nid] call ARC_fnc_stateSet;
["activeIedEvidenceCreatedAt", serverTime] call ARC_fnc_stateSet;
["activeIedEvidenceCollected", false] call ARC_fnc_stateSet;
["activeIedEvidenceCollectedAt", -1] call ARC_fnc_stateSet;
["activeIedEvidenceCollectedBy", ""] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_activeIedEvidenceNetId", _nid, true];

private _label = format ["IED_EVIDENCE:%1", _taskId];
[_obj, _posE, -1, 20, _label] call ARC_fnc_cleanupRegister;

// Attach “Collect evidence” action on all clients (JIP safe)
[_obj] remoteExec ["ARC_fnc_iedClientAddEvidenceAction", 0, true];

// If Phase 5 logistics is already enabled for this incident, enable ACE logistics on the evidence prop (JIP safe).
private _transportEnabled = ["activeIedEvidenceTransportEnabled", false] call ARC_fnc_stateGet;
if (!(_transportEnabled isEqualType true) && !(_transportEnabled isEqualType false)) then { _transportEnabled = false; };

private _mode = missionNamespace getVariable ["ARC_eodRtbEvidenceMode", "ACE_CARGO"]; 
if (!(_mode isEqualType "")) then { _mode = "ACE_CARGO"; };
_mode = toUpper (trim _mode);

if (_transportEnabled && { _mode isEqualTo "ACE_CARGO" }) then
{
    private _cargoSize = missionNamespace getVariable ["ARC_iedEvidenceCargoSize", 1];
    if (!(_cargoSize isEqualType 0) || { _cargoSize < 0 }) then { _cargoSize = 1; };
    private _enCarry = missionNamespace getVariable ["ARC_iedEvidenceCarryEnabled", true]; if (!(_enCarry isEqualType true) && !(_enCarry isEqualType false)) then { _enCarry = true; };
    private _enDrag  = missionNamespace getVariable ["ARC_iedEvidenceDragEnabled", true]; if (!(_enDrag isEqualType true) && !(_enDrag isEqualType false)) then { _enDrag = true; };
    [_nid, _cargoSize, _enCarry, _enDrag] remoteExec ["ARC_fnc_iedClientEnableEvidenceLogistics", 0, true];
};

true
