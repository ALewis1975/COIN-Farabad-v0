/*
    ARC_fnc_threatVirtualPoolInit

    Server-only. Initialises the virtual OpFor group pool at mission startup.
    For every named location (from ARC_worldNamedLocations) outside protected
    BLUFOR zones, one or more virtual group records are appended to the existing
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
    diag_log "[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: pool already seeded — running protected-zone sanitize pass.";

    // Protected zones list (configurable; defaults cover BLUFOR-controlled zones)
    private _pzMig = missionNamespace getVariable ["ARC_threatVirtualProtectedZones", ["Airbase", "GreenZone", "MilitaryBase"]];
    if (!(_pzMig isEqualType [])) then { _pzMig = ["Airbase", "GreenZone", "MilitaryBase"]; };

    // Named locations for anchor-position lookup during relocation
    private _migLocs = missionNamespace getVariable ["ARC_worldNamedLocations", []];
    if (!(_migLocs isEqualType [])) then { _migLocs = []; };

    // KV helpers (pairs-array pattern, sqflint compat — no HashMap methods)
    private _migKvGet = {
        params ["_pairs", "_key", "_default"];
        if (!(_pairs isEqualType [])) exitWith { _default };
        private _val = _default;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key })
            exitWith { _val = _x select 1; }; } forEach _pairs;
        _val
    };
    private _migKvSet = {
        params ["_pairs", "_key", "_value"];
        if (!(_pairs isEqualType [])) then { _pairs = []; };
        private _idx = -1;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key })
            exitWith { _idx = _forEachIndex; }; } forEach _pairs;
        if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
        _pairs
    };

    private _migDirty = false;

    {
        if (!(_x isEqualType [])) then { continue; };
        private _migRec = _x;
        private _migRi  = _forEachIndex;

        // Only process VIRTUAL_OPFOR records
        private _migType = [_migRec, "type", ""] call _migKvGet;
        if (!(_migType isEqualTo "VIRTUAL_OPFOR")) then { continue; };

        private _migPos = [_migRec, "pos", []] call _migKvGet;
        if (!(_migPos isEqualType []) || { (count _migPos) < 2 }) then { continue; };

        private _migPosZone = [_migPos] call ARC_fnc_worldGetZoneForPos;
        if (!(_migPosZone in _pzMig)) then { continue; };

        // This record sits inside a protected zone — attempt relocation
        private _migAnchorId = [_migRec, "anchorLocationId", ""] call _migKvGet;
        private _migAnchorPos = [];
        if (!(_migAnchorId isEqualTo "")) then {
            {
                _x params [["_mlid", "", [""]], ["_mlDisplayName", "", [""]], ["_mlpos", [], [[]]]];
                if (!(_mlDisplayName isEqualType "")) then { continue; };
                if (_mlid isEqualTo _migAnchorId) exitWith { _migAnchorPos = +_mlpos; };
            } forEach _migLocs;
        };

        // Base position for offset search: anchor if available, else current (bad) pos
        private _migBaseP3 = if ((count _migAnchorPos) >= 2) then { +_migAnchorPos } else { +_migPos };
        if ((count _migBaseP3) == 2) then { _migBaseP3 pushBack 0; };

        // Try up to 10 random offsets to find a position outside every protected zone
        private _migSafePos = [];
        for "_migAttempt" from 1 to 10 do {
            if ((count _migSafePos) >= 2) exitWith {};
            private _mox = random 300 - 150;
            private _moy = random 300 - 150;
            private _mCand = [(_migBaseP3 select 0) + _mox, (_migBaseP3 select 1) + _moy, 0];
            private _mCandZone = [_mCand] call ARC_fnc_worldGetZoneForPos;
            if (!(_mCandZone in _pzMig)) then { _migSafePos = _mCand; };
        };

        private _migVgId = [_migRec, "vgroup_id", "?"] call _migKvGet;
        if ((count _migSafePos) < 2) then {
            // Could not relocate — log warning; drift/spawn guards will prevent materialisation
            diag_log format ["[ARC][VPOOL][WARN] ARC_fnc_threatVirtualPoolInit: migration — no safe position found for %1 (zone=%2); spawn/drift guards will suppress.",
                _migVgId, _migPosZone];
        } else {
            _migRec = [_migRec, "pos", _migSafePos] call _migKvSet;
            _existing set [_migRi, _migRec];
            _migDirty = true;
            diag_log format ["[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: migration — relocated %1 out of protected zone=%2 to %3",
                _migVgId, _migPosZone, _migSafePos];
        };
    } forEach _existing;

    if (_migDirty) then {
        ["threat_v0_records", _existing] call ARC_fnc_stateSet;
    };

    diag_log "[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: sanitize pass complete — starting tick loop.";
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

// Protected zones: VIRTUAL_OPFOR must never seed, drift into, or spawn inside these zones.
// Configurable via ARC_threatVirtualProtectedZones; defaults cover BLUFOR-controlled zones.
private _protectedZones = missionNamespace getVariable ["ARC_threatVirtualProtectedZones", ["Airbase", "GreenZone", "MilitaryBase"]];
if (!(_protectedZones isEqualType [])) then { _protectedZones = ["Airbase", "GreenZone", "MilitaryBase"]; };

// Airbase exclusion: skip locations inside any protected zone
private _zones = missionNamespace getVariable ["ARC_worldZones", []];
if (!(_zones isEqualType [])) then { _zones = []; };

// Unit class list (mirror of opsPatrolOnActivate default)
private _unitClasses = missionNamespace getVariable ["ARC_opforPatrolUnitClasses", []];
if (!(_unitClasses isEqualType []) || {(count _unitClasses) == 0}) then {
    _unitClasses = ["O_G_Soldier_F", "O_G_Soldier_GL_F", "O_G_Soldier_AR_F", "O_G_medic_F", "O_G_Soldier_TL_F"];
};

// Filter out classnames absent from CfgVehicles to prevent null-object crashes on createUnit
private _validInitClasses = [];
{ if (isClass (configFile >> "CfgVehicles" >> _x)) then { _validInitClasses pushBack _x; }; } forEach _unitClasses;
if ((count _validInitClasses) < (count _unitClasses)) then {
    diag_log format ["[ARC][VPOOL][WARN] ARC_fnc_threatVirtualPoolInit: %1 class(es) missing from CfgVehicles — filtered. Valid: %2",
        (count _unitClasses) - (count _validInitClasses), _validInitClasses];
};
if ((count _validInitClasses) == 0) then {
    diag_log "[ARC][VPOOL][WARN] ARC_fnc_threatVirtualPoolInit: all unit classes invalid — reverting to vanilla defaults.";
    _unitClasses = ["O_G_Soldier_F", "O_G_Soldier_GL_F", "O_G_Soldier_AR_F", "O_G_medic_F", "O_G_Soldier_TL_F"];
} else {
    _unitClasses = _validInitClasses;
};

private _records    = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _seq    = ["threat_v0_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0)) then { _seq = 0; };

private _maxGroups = missionNamespace getVariable ["ARC_threatVirtualPoolMaxGroups", 96];
if (!(_maxGroups isEqualType 0)) then { _maxGroups = 96; };
_maxGroups = (_maxGroups max 8) min 400;

private _created = 0;
private _now     = serverTime;
private _capReached = false;
private _processedLocations = 0;

{
    if (_capReached) exitWith {};
    _processedLocations = _processedLocations + 1;

    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]]];

    if (!(_pos isEqualType []) || {(count _pos) < 2}) then { continue; };

    private _p3 = +_pos;
    if ((count _p3) == 2) then { _p3 pushBack 0; };

    // Skip if inside any protected zone (intentional: OPFOR must not seed near airbase/green zone)
    private _zone = [_p3] call ARC_fnc_worldGetZoneForPos;
    if (_zone in _protectedZones) then { continue; };

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
        if (_created >= _maxGroups) exitWith { _capReached = true; };

        _seq = _seq + 1;
        private _vgId = format ["vg_%1_%2", _seq, floor (random 1e5)];

        // Offset position so groups don't stack at the exact location centre.
        // Retry up to 5 times to ensure the final position is outside all protected zones.
        // (A named location just outside a zone boundary could otherwise drift a group inside.)
        private _vgPos = [];
        for "_seedAttempt" from 1 to 5 do {
            if ((count _vgPos) >= 2) exitWith {};
            private _offX = random 200 - 100;
            private _offY = random 200 - 100;
            private _cand = [(_p3 select 0) + _offX, (_p3 select 1) + _offY, 0];
            private _cZone = [_cand] call ARC_fnc_worldGetZoneForPos;
            if (!(_cZone in _protectedZones)) then { _vgPos = _cand; };
        };

        if ((count _vgPos) < 2) then {
            // All offset candidates landed in a protected zone — skip this group
            diag_log format ["[ARC][VPOOL][WARN] ARC_fnc_threatVirtualPoolInit: %1 all offset candidates in protected zone — skipping virtual group.", _id];
        } else {

            private _strength = 2 + (round (random 3)); // 2–5 units

            private _rec = [
                ["vgroup_id",          _vgId],
                ["type",               "VIRTUAL_OPFOR"],
                ["state",              "VIRTUAL_DORMANT"],
                ["faction",            "OPFOR_INS"],
                ["pos",                _vgPos],
                ["strength",           _strength],
                ["anchorLocationId",   _id],
                // Human-readable location label for diagnostics/AAR correlation.
                ["anchorLocationName", _displayName],
                ["spawnedUnits",       []],
                ["lastMoved",          _now],
                ["lastPlayerNearTs",   -1]
            ];

            _records pushBack _rec;
            _created = _created + 1;

        }; // end protected-zone guard
    };

} forEach _locations;

if (_capReached) then
{
    private _skippedLocations = ((count _locations) - _processedLocations) max 0;
    diag_log format ["[ARC][VPOOL][WARN] ARC_fnc_threatVirtualPoolInit: cap reached at %1/%2 virtual groups; skippedLocations=%3.",
        _created, _maxGroups, _skippedLocations];
};

["threat_v0_seq",              _seq]    call ARC_fnc_stateSet;
["threat_v0_records",          _records] call ARC_fnc_stateSet;
["threat_v0_vgroup_active_index", []]   call ARC_fnc_stateSet;

diag_log format ["[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolInit: created %1 virtual group record(s) (cap=%2).", _created, _maxGroups];

// Start the recurring pool tick loop
[] call ARC_fnc_threatVirtualPoolTick;

_created
