/*
    ARC_fnc_airbaseOrbatPopulate

    Server-only. Dynamically spawns ambient personnel and vehicles for the 8 ORBAT
    layers on Joint Base Farabad that have no Eden-placed units:

      1. REDTAIL 6 / Staff        — 332 AEW HQ (Wing Cdr + wing staff)
      2. Aerial Port              — APOD cargo/pax handlers (332 AMXS ground crew)
      3. LIFELINE ER/SURG/WARD    — 332 EMDG hospital personnel
      4. Ambulances / CCPs        — on-base medical vehicles with crew
      5. Flightline Security      — SENTRY flightline guard posts (332 ESFG)
      6. SENTRY QRF               — on-base quick reaction force with vehicle
      7. 1-73 CAV Troops A & B    — THUNDER cavalry troops at CAV HQ
      8. DUSTOFF crew             — 159 MEDEVAC flight crew on pad alert

    All positions anchor to existing mission.sqm markers via getMarkerPos.
    If a marker is absent (pos = [0,0,0]) the slot is silently skipped.

    Units are:
      - spawned in dedicated server-side groups (west)
      - unarmed ambient animation applied via ARC_fnc_airbaseCrewIdleStart
      - AUTOTARGET and TARGET AI disabled (ambient only; not combatants)
      - registered in "airbase_v1_orbat_units" (ARRAY, global, mission namespace)

    Vehicles (ambulances, QRF HMMWV) are created separately and stored in
    "airbase_v1_orbat_vehicles" for optional cleanup.

    Feature flag:
      airbase_v1_orbat_populate_enabled   BOOL  (set in initServer.sqf)

    Returns:
      NUMBER — total units spawned (0 on gate exit)
*/

if (!isServer) exitWith { 0 };
if !(["airbaseOrbatPopulate"] call ARC_fnc_airbaseRuntimeEnabled) exitWith { 0 };
if !(missionNamespace getVariable ["airbase_v1_orbat_populate_enabled", false]) exitWith { 0 };

if (missionNamespace getVariable ["airbase_v1_orbat_populate_ran", false]) exitWith { 0 };
missionNamespace setVariable ["airbase_v1_orbat_populate_ran", true];

diag_log "[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: starting ORBAT dynamic population";

private _allUnits    = [];
private _allVehicles = [];

// ---------------------------------------------------------------------------
// Helper: create a group of units near a marker, apply idle animation.
//
// _marker        STRING  — name of existing mission.sqm marker
// _classArray    ARRAY   — unit classnames (cycled if count < _count)
// _count         NUMBER  — number of units to spawn
// _spreadRadius  NUMBER  — metres radius around marker for unit placement
// _dir           NUMBER  — base facing direction (degrees)
//
// Returns ARRAY of created units (may be [] if marker absent).
// ---------------------------------------------------------------------------
private _fnSpawnUnitsAtMarker = {
    params [
        ["_marker",      "",  [""]],
        ["_classArray",  [],  [[]]],
        ["_count",       1,   [0]],
        ["_spreadRadius", 8,  [0]],
        ["_dir",         0,   [0]]
    ];

    private _pos = getMarkerPos _marker;
    if (_pos isEqualTo [0,0,0]) exitWith {
        diag_log format ["[ARC][WARN] ARC_fnc_airbaseOrbatPopulate: marker '%1' absent — slot skipped", _marker];
        []
    };

    private _units = [];
    private _nCls  = count _classArray;
    if (_nCls == 0) exitWith { [] };

    private _grp = createGroup [west, true];

    for "_i" from 0 to (_count - 1) do {
        private _cls = _classArray select (_i mod _nCls);

        // Scatter placement within spread radius
        private _angle   = _i * (360 / _count);
        private _dist    = linearConversion [0, _count - 1, _i, 2, _spreadRadius, false];
        private _offset  = [(_pos select 0) + (_dist * sin _angle),
                            (_pos select 1) + (_dist * cos _angle),
                            _pos select 2];

        // Prefer surface-snapped empty position, fall back to raw offset
        private _spawnPos = [_offset, 1, 3, 1, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_spawnPos isEqualTo [] || { _spawnPos isEqualTo [0,0,0] }) then {
            _spawnPos = _offset;
        };

        private _unit = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
        if (isNull _unit) then { continue; };

        _unit setDir (_dir + (_i * (360 / _count)));
        _unit disableAI "AUTOTARGET";
        _unit disableAI "TARGET";
        _unit disableAI "MOVE";
        _unit setCombatMode "BLUE";
        _unit setBehaviour "SAFE";

        _units pushBack _unit;
    };

    // Apply idle ambient animations
    [_units] call ARC_fnc_airbaseCrewIdleStart;

    _units
};

// ---------------------------------------------------------------------------
// Helper: create units at a given world position (no marker needed).
//
// _pos           ARRAY   — [x, y, z] world position
// _classArray    ARRAY   — unit classnames (cycled if count < _count)
// _count         NUMBER  — number of units to spawn
// _spreadRadius  NUMBER  — metres radius for unit placement
// _dir           NUMBER  — base facing direction (degrees)
//
// Returns ARRAY of created units.
// ---------------------------------------------------------------------------
private _fnSpawnUnitsAtPos = {
    params [
        ["_pos",         [0,0,0], [[]]],
        ["_classArray",  [],      [[]]],
        ["_count",       1,       [0]],
        ["_spreadRadius", 8,      [0]],
        ["_dir",         0,       [0]]
    ];

    private _units = [];
    private _nCls  = count _classArray;
    if (_nCls == 0) exitWith { [] };
    if (_pos isEqualTo [0,0,0]) exitWith { [] };

    private _grp = createGroup [west, true];

    for "_i" from 0 to (_count - 1) do {
        private _cls = _classArray select (_i mod _nCls);

        private _angle   = _i * (360 / _count);
        private _dist    = linearConversion [0, _count - 1, _i, 2, _spreadRadius, false];
        private _offset  = [(_pos select 0) + (_dist * sin _angle),
                            (_pos select 1) + (_dist * cos _angle),
                            _pos select 2];

        private _spawnPos = [_offset, 1, 3, 1, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_spawnPos isEqualTo [] || { _spawnPos isEqualTo [0,0,0] }) then {
            _spawnPos = _offset;
        };

        private _unit = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
        if (isNull _unit) then { continue; };

        _unit setDir (_dir + (_i * (360 / _count)));
        _unit disableAI "AUTOTARGET";
        _unit disableAI "TARGET";
        _unit disableAI "MOVE";
        _unit setCombatMode "BLUE";
        _unit setBehaviour "SAFE";

        _units pushBack _unit;
    };

    [_units] call ARC_fnc_airbaseCrewIdleStart;
    _units
};

// ---------------------------------------------------------------------------
// Helper: create a single vehicle with optional crew, anchored to a marker.
//
// _marker       STRING  — anchor marker
// _vehClass     STRING  — vehicle classname
// _driverClass  STRING  — unit classname for driver (or "" for no driver)
// _cargoClasses ARRAY   — unit classnames for cargo seats
// _offsetVec    ARRAY   — [dx, dz] offset in metres from marker pos
// _dir          NUMBER  — vehicle facing direction (degrees)
//
// Returns ARRAY [vehicle, ARRAY<units>] or [objNull, []] on failure.
// ---------------------------------------------------------------------------
private _fnSpawnVehicleAtMarker = {
    params [
        ["_marker",       "",  [""]],
        ["_vehClass",     "",  [""]],
        ["_driverClass",  "",  [""]],
        ["_cargoClasses", [],  [[]]],
        ["_offsetVec",    [0,0], [[]]],
        ["_dir",          0,   [0]]
    ];

    private _pos = getMarkerPos _marker;
    if (_pos isEqualTo [0,0,0]) exitWith {
        diag_log format ["[ARC][WARN] ARC_fnc_airbaseOrbatPopulate: marker '%1' absent — vehicle slot skipped", _marker];
        [objNull, []]
    };

    private _spawnPos = [
        (_pos select 0) + (_offsetVec select 0),
        (_pos select 1) + (_offsetVec select 1),
        _pos select 2
    ];

    private _veh = createVehicle [_vehClass, _spawnPos, [], 0, "NONE"];
    if (isNull _veh) exitWith { [objNull, []] };

    _veh setDir _dir;
    _veh setVelocity [0,0,0];

    private _grp   = createGroup [west, true];
    private _units = [];

    // Driver
    if !(_driverClass isEqualTo "") then {
        private _d = _grp createUnit [_driverClass, _spawnPos, [], 0, "NONE"];
        if (!isNull _d) then {
            _d disableAI "AUTOTARGET";
            _d disableAI "TARGET";
            _d disableAI "MOVE";
            moveOut _d;
            _d moveInDriver _veh;
            _units pushBack _d;
        };
    };

    // Cargo
    {
        private _c = _grp createUnit [_x, _spawnPos, [], 0, "NONE"];
        if (!isNull _c) then {
            _c disableAI "AUTOTARGET";
            _c disableAI "TARGET";
            _c disableAI "MOVE";
            moveOut _c;
            _c moveInCargo _veh;
            _units pushBack _c;
        };
    } forEach _cargoClasses;

    [_veh, _units]
};

// ===========================================================================
// 1.  REDTAIL 6 / Wing Staff  (332 AEW HQ)
//     Layer: 01.2) 332 AEW HQ (USAF Host Wing) [REDTAIL] → REDTAIL 6 / Staff
//     Anchor: ARC_m_base_avn_hq  [6690, 1554]
//     ORBAT: Wing Commander (REDTAIL 6) + Deputy Wing Cdr + 2 wing staff officers
// ===========================================================================
private _redtailUnits = [
    "ARC_m_base_avn_hq",
    ["rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman"],
    4, 5, 180
] call _fnSpawnUnitsAtMarker;

if (count _redtailUnits > 0) then {
    (_redtailUnits select 0) setUnitRank "COLONEL";
    if (count _redtailUnits > 1) then { (_redtailUnits select 1) setUnitRank "LIEUTENANT COLONEL"; };
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: REDTAIL staff spawned (%1 units)", count _redtailUnits];
};
_allUnits append _redtailUnits;

// ===========================================================================
// 2.  Aerial Port / APOD cargo handlers
//     Layer: 02.3) Aerial Port (cargo/pax handling)
//     Anchor: arc_m_base_civilian_terminal_01  [5947, 2325]
//     ORBAT: 332 AMXS cargo handlers in ground crew wear
// ===========================================================================
private _portUnits = [
    "arc_m_base_civilian_terminal_01",
    ["FIR_USAF_GroundCrew_1", "FIR_USAF_GroundCrew_2_ABU",
     "FIR_USAF_GroundCrew_1", "FIR_USAF_GroundCrew_2_ABU"],
    4, 8, 0
] call _fnSpawnUnitsAtMarker;

if (count _portUnits > 0) then {
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: Aerial Port handlers spawned (%1 units)", count _portUnits];
};
_allUnits append _portUnits;

// ===========================================================================
// 3.  LIFELINE medical personnel — 332 EMDG / Theater Hospital
//     Layer: 03.1) 332 EMDG / Theater Hospital [LIFELINE] → ER / SURG / WARD
//     Anchor: arc_m_base_theater_hospital  [5714, 2344]
//     ORBAT: USAF flight surgeons and medical technicians (ABU uniform)
// ===========================================================================
private _lifelineUnits = [
    "arc_m_base_theater_hospital",
    ["rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman",
     "rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman", "rhsusf_airforce_security_force_rifleman"],
    6, 12, 90
] call _fnSpawnUnitsAtMarker;

if (count _lifelineUnits > 0) then {
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: LIFELINE medical staff spawned (%1 units)", count _lifelineUnits];
};
_allUnits append _lifelineUnits;

// ===========================================================================
// 4.  Ambulances / CCPs (on-base)
//     Layer: 03.2) Ambulances / CCPs (on-base)
//     Anchor: arc_m_base_theater_hospital  [5714, 2344]
//     ORBAT: 2 on-base ambulances (UK3CB Hilux Ambulance) with medic crews
// ===========================================================================
private _amb1Result = [
    "arc_m_base_theater_hospital",
    "UK3CB_C_Hilux_Ambulance",
    "rhsusf_airforce_security_force_rifleman",
    ["rhsusf_airforce_security_force_rifleman"],
    [15, 5],
    270
] call _fnSpawnVehicleAtMarker;

private _amb2Result = [
    "arc_m_base_theater_hospital",
    "UK3CB_C_Hilux_Ambulance",
    "rhsusf_airforce_security_force_rifleman",
    ["rhsusf_airforce_security_force_rifleman"],
    [15, -5],
    270
] call _fnSpawnVehicleAtMarker;

{
    if (!(isNull (_x select 0))) then {
        _allVehicles pushBack (_x select 0);
        _allUnits append (_x select 1);
    };
} forEach [_amb1Result, _amb2Result];

if (count _allVehicles > 0) then {
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: %1 ambulance(s) spawned", count _allVehicles];
};

// ===========================================================================
// 5.  Flightline Security (SENTRY)
//     Layer: 04.1.2) Flightline Security
//     Anchor: ARC_m_base_usaf_pilot_hangar  [6559, 1586]
//     ORBAT: 332 ESFG flightline guards at hangar/ramp access points
// ===========================================================================
private _sentryFlightlineUnits = [
    "ARC_m_base_usaf_pilot_hangar",
    ["rhsusf_airforce_security_force_rifleman"],
    4, 10, 180
] call _fnSpawnUnitsAtMarker;

if (count _sentryFlightlineUnits > 0) then {
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: Flightline Security spawned (%1 units)", count _sentryFlightlineUnits];
};
_allUnits append _sentryFlightlineUnits;

// ===========================================================================
// 6.  SENTRY QRF (on-base)
//     Layer: 04.1.3) QRF (on-base)
//     Anchor: arc_m_base_police_hq  [5281, 2628]
//     ORBAT: 332 ESFG QRF — 5-man element + 1 HMMWV
// ===========================================================================
private _qrfUnits = [
    "arc_m_base_police_hq",
    ["rhsusf_airforce_security_force_rifleman"],
    5, 8, 0
] call _fnSpawnUnitsAtMarker;

if (count _qrfUnits > 0) then {
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: SENTRY QRF spawned (%1 units)", count _qrfUnits];
};
_allUnits append _qrfUnits;

// QRF vehicle: HMMWV at police HQ
private _qrfVehResult = [
    "arc_m_base_police_hq",
    "rhsusf_m1043_d",
    "",
    [],
    [12, 0],
    0
] call _fnSpawnVehicleAtMarker;

if (!(isNull (_qrfVehResult select 0))) then {
    _allVehicles pushBack (_qrfVehResult select 0);
    diag_log "[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: SENTRY QRF HMMWV spawned";
};

// ===========================================================================
// 7.  1-73 CAV Troops A & B  [THUNDER]
//     Layer: 04.3.1) 1-73 CAV (Airborne) [THUNDER] → Troop A / Troop B
//     Anchor: arc_m_base_1_73_CAV_hq  [6142, 2310]
//     ORBAT: THUNDER Troop A and Troop B — air cav dismount elements
// ===========================================================================
private _cavClassPool = [
    "rhsusf_army_ocp_squadleader",
    "rhsusf_army_ocp_rifleman",
    "rhsusf_army_ocp_rifleman",
    "rhsusf_army_ocp_riflemanl",
    "rhsusf_army_ocp_teamleader"
];

// Troop A — offset north-west of CAV HQ
private _cavHQPos = getMarkerPos "arc_m_base_1_73_CAV_hq";
if (!(_cavHQPos isEqualTo [0,0,0])) then {
    private _troopAPos = [(_cavHQPos select 0) - 20, (_cavHQPos select 1) + 15, 0];
    private _troopAUnits = [
        _troopAPos,
        _cavClassPool,
        5, 7, 270
    ] call _fnSpawnUnitsAtPos;

    if (count _troopAUnits > 0) then {
        (_troopAUnits select 0) setUnitRank "CAPTAIN";
        diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: 1-73 CAV Troop A spawned (%1 units)", count _troopAUnits];
    };
    _allUnits append _troopAUnits;
};

// Troop B — offset south-east of CAV HQ
if (!(_cavHQPos isEqualTo [0,0,0])) then {
    private _troopBPos = [(_cavHQPos select 0) + 20, (_cavHQPos select 1) - 15, 0];
    private _troopBUnits = [
        _troopBPos,
        _cavClassPool,
        5, 7, 90
    ] call _fnSpawnUnitsAtPos;

    if (count _troopBUnits > 0) then {
        (_troopBUnits select 0) setUnitRank "CAPTAIN";
        diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: 1-73 CAV Troop B spawned (%1 units)", count _troopBUnits];
    };
    _allUnits append _troopBUnits;
};

// ===========================================================================
// 8.  DUSTOFF crew  [09.2.6 MEDEVAC Flight]
//     Layer: 09.2.6) MEDEVAC Flight [DUSTOFF]
//     Anchor: arc_rotary_pad_6  [6885, 1669]
//     ORBAT: 159 MEDEVAC BN crew at pad alert — 2 pilots + 2 crew on standby
// ===========================================================================
private _dustoffUnits = [
    "arc_rotary_pad_6",
    ["rhsusf_army_ocp_helipilot", "rhsusf_army_ocp_helipilot",
     "rhsusf_army_ocp_helicrew",  "rhsusf_army_ocp_helicrew"],
    4, 6, 0
] call _fnSpawnUnitsAtMarker;

if (count _dustoffUnits > 0) then {
    (_dustoffUnits select 0) setUnitRank "CAPTAIN";
    diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: DUSTOFF crew spawned (%1 units)", count _dustoffUnits];
};
_allUnits append _dustoffUnits;

// ===========================================================================
// Publish spawned units + vehicles to mission namespace for optional cleanup
// ===========================================================================
missionNamespace setVariable ["airbase_v1_orbat_units",    _allUnits,    false];
missionNamespace setVariable ["airbase_v1_orbat_vehicles", _allVehicles, false];

private _nUnits = count _allUnits;
private _nVehs  = count _allVehicles;

diag_log format ["[ARC][INFO] ARC_fnc_airbaseOrbatPopulate: complete — %1 units, %2 vehicles", _nUnits, _nVehs];

_nUnits
