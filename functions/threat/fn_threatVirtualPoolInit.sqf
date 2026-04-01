/*
    ARC_fnc_threatVirtualPoolInit

    Server-only. Initialises the virtual OpFor group pool at mission startup.
    For every named location (from ARC_worldNamedLocations) outside the airbase
    exclusion zone, one or more virtual group records are appended to the existing
    threat_v0_records pairs-array store.

    Virtual group records are identified by:
        type  = "VIRTUAL_OPFOR"
        state = "VIRTUAL_DORMANT" | "VIRTUAL_ACTIVE" | "PHYSICAL"

    These are clearly distinct from existing IED/VBIED threat states (CREATED, ACTIVE,
    CLOSED, CLEANED) so they do not interfere with the rest of the threat system.

    Group count per location is scaled by the strategic tier from ARC_worldObjectiveIndex
    (HIGH → 2-3, MED → 1-2, LOW → 1). Falls back to 1 if index is absent.

    Must be called AFTER ARC_fnc_threatInit and ARC_fnc_worldInit.

    State written:
        threat_v0_records              - new vgroup records appended (persisted)
        threat_v0_vgroup_active_index  - list of vgroup IDs in PHYSICAL state (persisted)

    After initialising state, starts the virtual pool tick loop by calling
    ARC_fnc_threatVirtualPoolTick.

    Returns: NUMBER - count of virtual groups created
*/

if (!isServer) exitWith {0};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {
    diag_log "[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: threat disabled — skipping virtual pool.";
    0
};

// Skip if already seeded (idempotent: check for any existing VIRTUAL_OPFOR records)
private _existing = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_existing isEqualType [])) then { _existing = []; };

private _alreadySeeded = false;
{
    if (_x isEqualType []) then {
        {
            if (_x isEqualType [] && {(count _x) >= 2} && {(_x select 0) isEqualTo "type"} && {(_x select 1) isEqualTo "VIRTUAL_OPFOR"}) exitWith {
                _alreadySeeded = true;
            };
        } forEach _x;
    };
    if (_alreadySeeded) exitWith {};
} forEach _existing;

if (_alreadySeeded) exitWith {
    diag_log "[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: pool already seeded — starting tick loop.";
    [] call ARC_fnc_threatVirtualPoolTick;
    0
};

private _locations = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_locations isEqualType [])) then { _locations = []; };

if ((count _locations) == 0) exitWith {
    diag_log "[ARC][VPOOL][WARN] ARC_fnc_threatVirtualPoolInit: ARC_worldNamedLocations empty — cannot seed pool.";
    0
};

// Strategic index for per-location group count scaling
private _objIndex = missionNamespace getVariable ["ARC_worldObjectiveIndex", createHashMap];
if (!(_objIndex isEqualType createHashMap)) then { _objIndex = createHashMap; };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// Airbase exclusion: skip locations inside the Airbase zone
private _zones = missionNamespace getVariable ["ARC_worldZones", []];
if (!(_zones isEqualType [])) then { _zones = []; };

// Unit class list (mirror of opsPatrolOnActivate default)
private _unitClasses = missionNamespace getVariable ["ARC_opforPatrolUnitClasses", []];
if (!(_unitClasses isEqualType []) || {(count _unitClasses) == 0}) then {
    _unitClasses = ["O_G_Soldier_F", "O_G_Soldier_GL_F", "O_G_Soldier_AR_F", "O_G_medic_F", "O_G_Soldier_TL_F"];
};

private _records    = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _seq    = ["threat_v0_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0)) then { _seq = 0; };

private _created = 0;
private _now     = serverTime;

{
    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]]];

    if (!(_pos isEqualType []) || {(count _pos) < 2}) then { continue; };

    private _p3 = +_pos;
    if ((count _p3) == 2) then { _p3 pushBack 0; };

    // Skip if inside Airbase zone
    private _zone = [_p3] call ARC_fnc_worldGetZoneForPos;
    if (_zone isEqualTo "Airbase") then { continue; };

    // Determine group count from strategic tier
    private _groupCount = 1;
    private _entry = [_objIndex, _id, []] call _hg;
    if (_entry isEqualType [] && {(count _entry) >= 2}) then {
        private _tier = _entry select 1;
        if (_tier isEqualTo "HIGH") then {
            _groupCount = 2 + (round (random 1)); // 2 or 3
        };
        if (_tier isEqualTo "MED") then {
            _groupCount = 1 + (round (random 1)); // 1 or 2
        };
    };

    for "_g" from 1 to _groupCount do {
        _seq = _seq + 1;
        private _vgId = format ["vg_%1_%2", _seq, floor (random 1e5)];

        // Small random position offset so groups don't all stack at the exact location centre
        private _offX = random 200 - 100;
        private _offY = random 200 - 100;
        private _vgPos = [(_p3 select 0) + _offX, (_p3 select 1) + _offY, 0];

        private _strength = 2 + (round (random 3)); // 2–5 units

        private _rec = [
            ["vgroup_id",          _vgId],
            ["type",               "VIRTUAL_OPFOR"],
            ["state",              "VIRTUAL_DORMANT"],
            ["faction",            "OPFOR_INS"],
            ["pos",                _vgPos],
            ["strength",           _strength],
            ["anchorLocationId",   _id],
            ["spawnedUnits",       []],
            ["lastMoved",          _now],
            ["lastPlayerNearTs",   -1]
        ];

        _records pushBack _rec;
        _created = _created + 1;
    };

} forEach _locations;

["threat_v0_seq",              _seq]    call ARC_fnc_stateSet;
["threat_v0_records",          _records] call ARC_fnc_stateSet;
["threat_v0_vgroup_active_index", []]   call ARC_fnc_stateSet;

diag_log format ["[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: created %1 virtual group record(s).", _created];

// Start the recurring pool tick loop
[] call ARC_fnc_threatVirtualPoolTick;

_created
