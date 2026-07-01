/*
    ARC_fnc_worldSpawnPatternResolve

    Server: resolve the transient task overlay for an Incident / Lead / civic
    mission from the spawn-pattern matrix (data/farabad_spawn_patterns.sqf).

    This is the consumption counterpart to ARC_fnc_worldSpawnPatternAudit. It is
    side-effect free (no spawning, no mission-state writes) — it only reads the
    matrix and returns the merged overlay definition that
    ARC_fnc_worldSpawnOverlayApply then spawns.

    Resolution order (matches the audit):
        1. Incident-type overlay (incidentOverlays[incidentType]) — the base layer.
        2. Lead-tag overlay (leadOverlays[leadTag]) takes precedence when present,
           driven by the lead fields rather than display-name string checks.
        3. Civic-subtype overlay (civicMissionOverlays[civicSubtype]) takes
           precedence when present (purpose-specific aid/governance/repair context).
    The most specific available overlay wins; lead/civic override the bare
    incident overlay. Placement / cleanupOwner / despawnPolicy come from the
    winning overlay.

    The matrix is parsed once and memoised in ARC_worldSpawnPatternCache so
    repeated incident inits do not re-preprocess the file.

    Params:
        0: STRING — incidentType (e.g. "RAID", "CHECKPOINT"); upper-cased internally.
        1: STRING — leadTag (e.g. "SUS_VEHICLE"); "" when not a lead-seeded task.
        2: STRING — civicSubtype (e.g. "MEDICAL_OUTREACH"); "" when not civic.
        3: STRING — zone id (e.g. "Airbase", "FarabadCity"); "" when none. Used to
                    select a zone-sensitive CHECKPOINT variant (issue #633 step 6).

    Returns: ARRAY of [key,value] pairs (empty array if no overlay resolves):
        ["overlay",       ARRAY of roleSpec]   task-added AI roles
        ["objects",       ARRAY of objectSpec] task-added props/vehicles
        ["placement",     STRING]
        ["cleanupOwner",  STRING]              INCIDENT | LEAD | NONE
        ["despawnPolicy", STRING]
        ["source",        STRING]              INCIDENT | LEAD | CIVIC (which table won)
        ["composition",   STRING]              optional deterministic composition key
*/

if (!isServer) exitWith {[]};

params [
    ["_incidentType", "", [""]],
    ["_leadTag",      "", [""]],
    ["_civicSubtype", "", [""]],
    ["_zone",         "", [""]]
];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _pairsToMap = {
    params ["_pairs"];
    private _m = createHashMap;
    if (!(_pairs isEqualType [])) exitWith { _m };
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then { _m set [_x select 0, _x select 1]; };
    } forEach _pairs;
    _m
};

// --- Load + memoise the matrix overlay tables ----------------------------
private _cache = missionNamespace getVariable ["ARC_worldSpawnPatternCache", createHashMap];
if (!(_cache isEqualType createHashMap)) then { _cache = createHashMap; };

private _incidentOverlays = [_cache, "incidentOverlays", createHashMap] call _hg;
private _leadOverlays     = [_cache, "leadOverlays", createHashMap] call _hg;
private _civicOverlays    = [_cache, "civicMissionOverlays", createHashMap] call _hg;

if (!(([_cache, "loaded", false] call _hg))) then {
    private _fileExistsFn = compile "params ['_p']; fileExists _p";
    private _patPath = "data\farabad_spawn_patterns.sqf";
    if ([_patPath] call _fileExistsFn) then {
        private _raw = call compile preprocessFileLineNumbers _patPath;
        if (_raw isEqualType []) then {
            private _root = [_raw] call _pairsToMap;
            _incidentOverlays = [[_root, "incidentOverlays", []] call _hg] call _pairsToMap;
            _leadOverlays     = [[_root, "leadOverlays", []] call _hg] call _pairsToMap;
            _civicOverlays    = [[_root, "civicMissionOverlays", []] call _hg] call _pairsToMap;
        } else {
            diag_log "[ARC][SPAWNPAT][WARN] ARC_fnc_worldSpawnPatternResolve: pattern file did not return an array.";
        };
    } else {
        diag_log "[ARC][SPAWNPAT][WARN] ARC_fnc_worldSpawnPatternResolve: data\farabad_spawn_patterns.sqf missing.";
    };
    _cache set ["incidentOverlays", _incidentOverlays];
    _cache set ["leadOverlays", _leadOverlays];
    _cache set ["civicMissionOverlays", _civicOverlays];
    _cache set ["loaded", true];
    missionNamespace setVariable ["ARC_worldSpawnPatternCache", _cache];
};

// --- Pick the winning overlay (civic > lead > incident) ------------------
private _typeU  = toUpper _incidentType;
private _leadU  = toUpper _leadTag;
private _civicU = toUpper _civicSubtype;

private _def    = [];
private _source = "";

if (!(_civicU isEqualTo "")) then {
    private _c = [_civicOverlays, _civicU, []] call _hg;
    if (_c isEqualType [] && { (count _c) > 0 }) then { _def = _c; _source = "CIVIC"; };
};

if ((count _def) == 0 && { !(_leadU isEqualTo "") }) then {
    private _l = [_leadOverlays, _leadU, []] call _hg;
    if (_l isEqualType [] && { (count _l) > 0 }) then { _def = _l; _source = "LEAD"; };
};

if ((count _def) == 0 && { !(_typeU isEqualTo "") }) then {
    // Zone-sensitive CHECKPOINT variant selection (issue #633 step 6). Map the
    // incident zone to a CHECKPOINT_* key; fall back to plain CHECKPOINT when
    // the variant is absent. All other incident types resolve directly.
    private _lookupKey = _typeU;
    if (_typeU isEqualTo "CHECKPOINT") then {
        private _zoneU = toUpper _zone;
        private _variant = "CHECKPOINT_RURAL";
        if (
            _zoneU isEqualTo "AIRBASE" ||
            { _zoneU isEqualTo "GREENZONE" } ||
            { _zoneU isEqualTo "MILITARYBASE" }
        ) then {
            _variant = "CHECKPOINT_GATE";
        } else {
            if (_zoneU isEqualTo "FARABADCITY") then {
                _variant = "CHECKPOINT_URBAN";
            };
        };
        private _vDef = [_incidentOverlays, _variant, []] call _hg;
        if (_vDef isEqualType [] && { (count _vDef) > 0 }) then { _lookupKey = _variant; };
    };
    private _i = [_incidentOverlays, _lookupKey, []] call _hg;
    if (_i isEqualType [] && { (count _i) > 0 }) then { _def = _i; _source = "INCIDENT"; };
};

if ((count _def) == 0) exitWith {[]};

// --- Normalise into the documented return shape --------------------------
private _m = [_def] call _pairsToMap;
private _overlay = [_m, "overlay", []] call _hg;
private _objects = [_m, "objects", []] call _hg;
private _composition = [_m, "composition", ""] call _hg;
if (!(_overlay isEqualType [])) then { _overlay = []; };
if (!(_objects isEqualType [])) then { _objects = []; };
if (!(_composition isEqualType "")) then { _composition = ""; };

// FOOD_WATER_DISTRIBUTION can resolve onto dense pedestrian courtyards (e.g. Grand Mosque).
// Replace the old haphazard radial spread with a deterministic aid-site composition
// consumed by ARC_fnc_worldSpawnOverlayApply via fw_* placement tags.
if (_civicU isEqualTo "FOOD_WATER_DISTRIBUTION") then {
    _composition = "FOOD_WATER_DISTRIBUTION";
    _overlay = [
        ["aid_worker",   "civ",  [2, 2], "hold",  "fw_aid"],
        ["fw_queue_civ", "civ",  [6, 6], "hold",  "fw_queue"],
        ["fw_liaison",   "civ",  [1, 1], "hold",  "fw_liaison"],
        ["local_sec",    "west", [2, 2], "guard", "fw_security"]
    ];
    _objects = [
        ["aid_table",       [1, 1], "fw_aid"],
        ["water_container", [2, 2], "fw_water"],
        ["supply_crate",    [2, 2], "fw_supply"],
        ["cargo_clutter",   [1, 1], "fw_supply"],
        ["barrier",         [1, 2], "fw_security"]
    ];
};

[
    ["overlay", _overlay],
    ["objects", _objects],
    ["placement", [_m, "placement", ""] call _hg],
    ["cleanupOwner", [_m, "cleanupOwner", "INCIDENT"] call _hg],
    ["despawnPolicy", [_m, "despawnPolicy", "INCIDENT_DESPAWN"] call _hg],
    ["source", _source],
    ["composition", _composition]
]