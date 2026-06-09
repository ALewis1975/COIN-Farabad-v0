/*
    ARC_fnc_worldSpawnPatternAudit

    Developer/debug diagnostics for the Incident / Lead / site spawn-pattern
    matrix (issue #633, step 1 / section 9).

    Read-only. Resolves every Incident catalog row, named location, terrain
    site type, and structured civic-mission row against
    data/farabad_spawn_patterns.sqf and reports, for each:
        - resolved marker / position reference
        - resolved purpose tag (place classification)
        - selected spawn pattern (baseline + incident/lead overlay)
        - AI count range and object count range
        - placement strategy
        - cleanup owner
        - warnings for: missing pattern, missing marker, no purpose mapping,
          or no baseline population

    This function does NOT spawn anything and does NOT mutate mission state. It
    is the diagnostic foundation for the later (separately-toggled) overlay
    spawning phases. It is gated behind ARC_spawnPatternsEnabled only to avoid
    log noise; resolution itself is side-effect free.

    Params:
        0: _verbose  BOOL (default false) - when true, diag_log every row.

    Returns: ARRAY of [key, value] pairs:
        ["rows",     ARRAY]   one report row per resolved entry
        ["warnings", ARRAY]   collected warning strings
        ["summary",  ARRAY]   [totalRows, locationCount, siteTypeCount,
                               incidentRowCount, civicRowCount, warningCount]

    Each report row is itself a pairs array:
        ["kind", STRING]            LOCATION | TERRAIN_SITE | INCIDENT | CIVIC
        ["ref", STRING]             location id / site type / marker / civic id
        ["purpose", STRING]         resolved purpose tag
        ["incidentType", STRING]    "" for non-incident rows; civic rows use the
                                    civic subtype here
        ["placement", STRING]
        ["aiRange", ARRAY]          [min, max] combined baseline + overlay
        ["objRange", ARRAY]         [min, max] combined baseline + overlay
        ["cleanupOwner", STRING]
        ["warnings", ARRAY]
*/

if (!isServer) exitWith {[]};

params [["_verbose", false, [false]]];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _fileExistsFn = compile "params ['_p']; fileExists _p";

// --- Load the spawn-pattern matrix into lookup HashMaps -------------------
private _patPath = "data\farabad_spawn_patterns.sqf";
if (!([_patPath] call _fileExistsFn)) exitWith {
    diag_log "[ARC][SPAWNPAT][WARN] worldSpawnPatternAudit: data\farabad_spawn_patterns.sqf missing.";
    []
};

private _pairsToMap = {
    params ["_pairs"];
    private _m = createHashMap;
    if (!(_pairs isEqualType [])) exitWith { _m };
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then { _m set [_x select 0, _x select 1]; };
    } forEach _pairs;
    _m
};

private _raw = call compile preprocessFileLineNumbers _patPath;
if (!(_raw isEqualType [])) exitWith {
    diag_log "[ARC][SPAWNPAT][WARN] worldSpawnPatternAudit: pattern file did not return an array.";
    []
};
private _root = [_raw] call _pairsToMap;

private _purposePatterns = [[_root, "purposePatterns", []] call _hg] call _pairsToMap;
private _locationPurposes = [[_root, "locationPurposes", []] call _hg] call _pairsToMap;
private _siteTypePurposes = [[_root, "siteTypePurposes", []] call _hg] call _pairsToMap;
private _incidentOverlays = [[_root, "incidentOverlays", []] call _hg] call _pairsToMap;
private _leadOverlays = [[_root, "leadOverlays", []] call _hg] call _pairsToMap;
private _civicMissionOverlays = [[_root, "civicMissionOverlays", []] call _hg] call _pairsToMap;

// --- Helpers --------------------------------------------------------------
// Sum [min,max] role/object count ranges from a specs array (index 2 holds the
// [min,max] pair for roleSpec; index 1 for objectSpec).
private _sumRange = {
    params ["_specs", "_idx"];
    private _mn = 0;
    private _mx = 0;
    if (_specs isEqualType []) then {
        {
            if (_x isEqualType [] && { (count _x) > _idx }) then {
                private _r = _x select _idx;
                if (_r isEqualType [] && { (count _r) >= 2 } && { (_r select 0) isEqualType 0 } && { (_r select 1) isEqualType 0 }) then {
                    _mn = _mn + (_r select 0);
                    _mx = _mx + (_r select 1);
                };
            };
        } forEach _specs;
    };
    [_mn, _mx]
};

private _patternRanges = {
    // Returns [[aiMin,aiMax],[objMin,objMax],placement,cleanupOwner] for a patternDef.
    params ["_def"];
    private _m = [_def] call _pairsToMap;
    private _ai = [[_m, "baselinePop", []] call _hg, 2] call _sumRange;
    private _ob = [[_m, "objects", []] call _hg, 1] call _sumRange;
    private _pl = [_m, "placement", ""] call _hg;
    private _co = [_m, "cleanupOwner", ""] call _hg;
    [_ai, _ob, _pl, _co]
};

private _overlayRanges = {
    // Returns [[aiMin,aiMax],[objMin,objMax],placement,cleanupOwner] for an overlayDef.
    params ["_def"];
    private _m = [_def] call _pairsToMap;
    private _ai = [[_m, "overlay", []] call _hg, 2] call _sumRange;
    private _ob = [[_m, "objects", []] call _hg, 1] call _sumRange;
    private _pl = [_m, "placement", ""] call _hg;
    private _co = [_m, "cleanupOwner", ""] call _hg;
    [_ai, _ob, _pl, _co]
};

private _rows = [];
private _warnings = [];
private _addWarn = {
    params ["_msg"];
    _warnings pushBack _msg;
};

// --- 1. Named-location coverage ------------------------------------------
private _named = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_named isEqualType [])) then { _named = []; };
// Fallback to the static export if the world registry has not initialised.
if ((count _named) == 0) then {
    private _wlPath = "data\farabad_world_locations.sqf";
    if ([_wlPath] call _fileExistsFn) then {
        private _wl = call compile preprocessFileLineNumbers _wlPath;
        if (_wl isEqualType [] && { (count _wl) >= 1 } && { (_wl select 0) isEqualType [] }) then {
            _named = _wl select 0;
        };
    };
};

private _locationCount = 0;
{
    if (!(_x isEqualType [])) then { continue; };
    private _id = _x param [0, "", [""]];
    if (_id isEqualTo "") then { continue; };
    _locationCount = _locationCount + 1;

    private _rowWarn = [];
    private _purpose = [_locationPurposes, _id, ""] call _hg;
    if (_purpose isEqualTo "") then {
        _purpose = "UNMAPPED";
        _rowWarn pushBack "no purpose mapping";
        [format ["[LOCATION] %1: no purpose mapping", _id]] call _addWarn;
    };

    private _aiR = [0, 0];
    private _obR = [0, 0];
    private _pl = "";
    private _co = "";
    if (_purpose isEqualTo "UNMAPPED") then {
        // nothing more to resolve
    } else {
        private _pat = [_purposePatterns, _purpose, []] call _hg;
        if (!(_pat isEqualType []) || { (count _pat) == 0 }) then {
            _rowWarn pushBack "missing pattern for purpose";
            [format ["[LOCATION] %1: purpose %2 has no pattern", _id, _purpose]] call _addWarn;
        } else {
            ([_pat] call _patternRanges) params ["_ai", "_ob", "_plv", "_cov"];
            _aiR = _ai; _obR = _ob; _pl = _plv; _co = _cov;
            if (!(_purpose isEqualTo "NO_BASELINE_POP") && { (_ai select 1) == 0 }) then {
                _rowWarn pushBack "no baseline population";
            };
        };
    };

    _rows pushBack [
        ["kind", "LOCATION"],
        ["ref", _id],
        ["purpose", _purpose],
        ["incidentType", ""],
        ["placement", _pl],
        ["aiRange", _aiR],
        ["objRange", _obR],
        ["cleanupOwner", _co],
        ["warnings", _rowWarn]
    ];
} forEach _named;

// --- 2. Terrain-site-type coverage ---------------------------------------
private _siteTypeCount = 0;
{
    private _st = _x;
    _siteTypeCount = _siteTypeCount + 1;
    private _rowWarn = [];
    private _purpose = [_siteTypePurposes, _st, ""] call _hg;
    private _aiR = [0, 0];
    private _obR = [0, 0];
    private _pl = "";
    private _co = "";
    if (_purpose isEqualTo "") then {
        _purpose = "UNMAPPED";
        _rowWarn pushBack "no purpose mapping";
        [format ["[TERRAIN_SITE] %1: no purpose mapping", _st]] call _addWarn;
    } else {
        private _pat = [_purposePatterns, _purpose, []] call _hg;
        if (!(_pat isEqualType []) || { (count _pat) == 0 }) then {
            _rowWarn pushBack "missing pattern for purpose";
            [format ["[TERRAIN_SITE] %1: purpose %2 has no pattern", _st, _purpose]] call _addWarn;
        } else {
            ([_pat] call _patternRanges) params ["_ai", "_ob", "_plv", "_cov"];
            _aiR = _ai; _obR = _ob; _pl = _plv; _co = _cov;
        };
    };
    _rows pushBack [
        ["kind", "TERRAIN_SITE"],
        ["ref", _st],
        ["purpose", _purpose],
        ["incidentType", ""],
        ["placement", _pl],
        ["aiRange", _aiR],
        ["objRange", _obR],
        ["cleanupOwner", _co],
        ["warnings", _rowWarn]
    ];
} forEach ([_siteTypePurposes] call (compile "params ['_m']; keys _m"));

// --- 3. Incident catalog coverage ----------------------------------------
private _markerPurpose = {
    // Best-effort marker -> purpose: ARC_loc_<Id> markers map back to a named
    // location id; everything else (gates, patrol/ied markers, district
    // markers) resolves by marker-name heuristics to a purpose tag.
    params ["_marker"];
    private _mk = _marker;
    private _up = toUpper _mk;
    // ARC_loc_<LocationId> -> look up the location id (case-insensitive).
    if ((_up find "ARC_LOC_") == 0) then {
        private _suffix = _mk select [8];
        private _hit = "";
        {
            if ((toUpper _x) isEqualTo (toUpper _suffix)) exitWith { _hit = _x; };
        } forEach ([_locationPurposes] call (compile "params ['_m']; keys _m"));
        if (!(_hit isEqualTo "")) exitWith { [_locationPurposes, _hit, ""] call _hg };
    };
    // Gate markers -> checkpoint.
    if ((_up find "GATE") >= 0) exitWith { "CHECKPOINT" };
    // Patrol / route / IED / district markers.
    if ((_up find "ARC_M_PATROL") == 0) exitWith { "MSR_ROAD" };
    if ((_up find "ARC_M_IED") == 0) exitWith { "MSR_ROAD" };
    if ((_up find "ARC_M_LOGISTICS") == 0) exitWith { "MSR_ROAD" };
    if ((_up find "ARC_M_CIVIL") == 0) exitWith { "MARKET" };
    if ((_up find "ARC_M_BASE_TOC") == 0) exitWith { "MILITARY" };
    if ((_up find "ARC_CIVLOC_") == 0) exitWith { "MARKET" };
    if ((_up find "MARKER_") == 0) exitWith { "MINE" };
    if ((_up find "MKR_AIRBASE") == 0) exitWith { "MILITARY" };
    ""
};

private _catalog = [];
private _basePath = "data\incident_markers.sqf";
if ([_basePath] call _fileExistsFn) then {
    private _base = call compile preprocessFileLineNumbers _basePath;
    if (_base isEqualType []) then { _catalog = _base; };
};
if (!(_catalog isEqualType [])) then { _catalog = []; };

private _incidentRowCount = 0;
{
    if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
    _x params ["_marker", "_display", "_type"];
    private _meta = _x param [3, []];
    if (!(_marker isEqualType "") || { !(_type isEqualType "") }) then { continue; };
    _incidentRowCount = _incidentRowCount + 1;
    _type = toUpper _type;

    private _rowWarn = [];

    // Where: marker must exist in the running mission (best-effort; static runs
    // have no markers so only warn when markers are present at all).
    private _markerKnown = (_marker in allMapMarkers);
    if ((count allMapMarkers) > 0 && { !_markerKnown }) then {
        _rowWarn pushBack "missing marker";
        [format ["[INCIDENT] %1 (%2): marker not present", _display, _marker]] call _addWarn;
    };

    // What place: purpose tag from marker.
    private _purpose = [_marker] call _markerPurpose;
    if (_purpose isEqualTo "") then {
        _purpose = "UNMAPPED";
        _rowWarn pushBack "no purpose mapping";
        [format ["[INCIDENT] %1 (%2): marker has no purpose mapping", _display, _marker]] call _addWarn;
    };

    // Lead tag (if this is a lead-seeded row) drives a lead overlay.
    private _metaMap = [_meta] call _pairsToMap;
    private _leadTag = toUpper ([_metaMap, "leadTag", ""] call _hg);

    // Baseline ranges from the purpose pattern.
    private _aiMin = 0; private _aiMax = 0; private _obMin = 0; private _obMax = 0;
    private _pl = ""; private _co = "INCIDENT";
    if (!(_purpose isEqualTo "UNMAPPED")) then {
        private _pat = [_purposePatterns, _purpose, []] call _hg;
        if (_pat isEqualType [] && { (count _pat) > 0 }) then {
            ([_pat] call _patternRanges) params ["_ai", "_ob", "_plv"];
            _aiMin = _aiMin + (_ai select 0); _aiMax = _aiMax + (_ai select 1);
            _obMin = _obMin + (_ob select 0); _obMax = _obMax + (_ob select 1);
            _pl = _plv;
        };
    };

    // Incident-type overlay.
    private _ov = [_incidentOverlays, _type, []] call _hg;
    if (!(_ov isEqualType []) || { (count _ov) == 0 }) then {
        _rowWarn pushBack "no incident overlay";
        [format ["[INCIDENT] %1 (%2): incident type %3 has no overlay", _display, _marker, _type]] call _addWarn;
    } else {
        ([_ov] call _overlayRanges) params ["_ai", "_ob", "_plv", "_cov"];
        _aiMin = _aiMin + (_ai select 0); _aiMax = _aiMax + (_ai select 1);
        _obMin = _obMin + (_ob select 0); _obMax = _obMax + (_ob select 1);
        if (!(_plv isEqualTo "")) then { _pl = _plv; };
        if (!(_cov isEqualTo "")) then { _co = _cov; };
    };

    // Lead overlay (additive) when a lead tag is present.
    if (!(_leadTag isEqualTo "")) then {
        private _lov = [_leadOverlays, _leadTag, []] call _hg;
        if (_lov isEqualType [] && { (count _lov) > 0 }) then {
            ([_lov] call _overlayRanges) params ["_ai", "_ob", "_plv", "_cov"];
            _aiMin = _aiMin + (_ai select 0); _aiMax = _aiMax + (_ai select 1);
            _obMin = _obMin + (_ob select 0); _obMax = _obMax + (_ob select 1);
            if (!(_plv isEqualTo "")) then { _pl = _plv; };
            if (!(_cov isEqualTo "")) then { _co = _cov; };
        };
    };

    _rows pushBack [
        ["kind", "INCIDENT"],
        ["ref", _marker],
        ["purpose", _purpose],
        ["incidentType", _type],
        ["placement", _pl],
        ["aiRange", [_aiMin, _aiMax]],
        ["objRange", [_obMin, _obMax]],
        ["cleanupOwner", _co],
        ["warnings", _rowWarn]
    ];
} forEach _catalog;

// --- 4. Structured civic-mission catalog coverage ------------------------
// Resolve civic "locations" entries using the same heuristics as incident markers.
private _locIdPurpose = {
    params ["_locRef"];
    [_locRef] call _markerPurpose
};

private _civicCatalog = [];
private _civicPath = "data\coin_civic_mission_catalog.sqf";
if ([_civicPath] call _fileExistsFn) then {
    private _cc = call compile preprocessFileLineNumbers _civicPath;
    if (_cc isEqualType []) then { _civicCatalog = _cc; };
};
if (!(_civicCatalog isEqualType [])) then { _civicCatalog = []; };

private _civicRowCount = 0;
{
    if (!(_x isEqualType [])) then { continue; };
    private _recMap = [_x] call _pairsToMap;
    private _id = [_recMap, "id", ""] call _hg;
    private _subtype = toUpper ([_recMap, "subtype", ""] call _hg);
    private _itype = toUpper ([_recMap, "incidentType", ""] call _hg);
    if (_id isEqualTo "" && { _subtype isEqualTo "" }) then { continue; };
    _civicRowCount = _civicRowCount + 1;

    private _rowWarn = [];

    // What place: purpose from the first resolvable location, else first site type.
    private _purpose = "";
    private _locs = [_recMap, "locations", []] call _hg;
    if (_locs isEqualType []) then {
        {
            private _p = [_x] call _locIdPurpose;
            if (!(_p isEqualTo "")) exitWith { _purpose = _p; };
        } forEach _locs;
    };
    if (_purpose isEqualTo "") then {
        private _sts = [_recMap, "siteTypes", []] call _hg;
        if (_sts isEqualType []) then {
            {
                private _p = [_siteTypePurposes, _x, ""] call _hg;
                if (!(_p isEqualTo "")) exitWith { _purpose = _p; };
            } forEach _sts;
        };
    };
    if (_purpose isEqualTo "") then {
        _purpose = "UNMAPPED";
        _rowWarn pushBack "no purpose mapping";
        [format ["[CIVIC] %1: no resolvable location/site purpose", _id]] call _addWarn;
    };

    private _aiMin = 0; private _aiMax = 0; private _obMin = 0; private _obMax = 0;
    private _pl = ""; private _co = "INCIDENT";

    // Baseline from purpose pattern.
    if (!(_purpose isEqualTo "UNMAPPED")) then {
        private _pat = [_purposePatterns, _purpose, []] call _hg;
        if (_pat isEqualType [] && { (count _pat) > 0 }) then {
            ([_pat] call _patternRanges) params ["_ai", "_ob", "_plv"];
            _aiMin = _aiMin + (_ai select 0); _aiMax = _aiMax + (_ai select 1);
            _obMin = _obMin + (_ob select 0); _obMax = _obMax + (_ob select 1);
            _pl = _plv;
        };
    };

    // Civic-subtype overlay (preferred). Fall back to the incident-type overlay
    // so legacy civic rows without a subtype mapping still resolve a task layer.
    private _ov = [_civicMissionOverlays, _subtype, []] call _hg;
    if (!(_ov isEqualType []) || { (count _ov) == 0 }) then {
        _rowWarn pushBack "no civic overlay";
        [format ["[CIVIC] %1: subtype %2 has no overlay", _id, _subtype]] call _addWarn;
        _ov = [_incidentOverlays, _itype, []] call _hg;
    };
    if (_ov isEqualType [] && { (count _ov) > 0 }) then {
        ([_ov] call _overlayRanges) params ["_ai", "_ob", "_plv", "_cov"];
        _aiMin = _aiMin + (_ai select 0); _aiMax = _aiMax + (_ai select 1);
        _obMin = _obMin + (_ob select 0); _obMax = _obMax + (_ob select 1);
        if (!(_plv isEqualTo "")) then { _pl = _plv; };
        if (!(_cov isEqualTo "")) then { _co = _cov; };
    };

    _rows pushBack [
        ["kind", "CIVIC"],
        ["ref", _id],
        ["purpose", _purpose],
        ["incidentType", _subtype],
        ["placement", _pl],
        ["aiRange", [_aiMin, _aiMax]],
        ["objRange", [_obMin, _obMax]],
        ["cleanupOwner", _co],
        ["warnings", _rowWarn]
    ];
} forEach _civicCatalog;

// --- 5. Class-pool resolvability diagnostics (issue #633 step 9) ----------
// For every distinct [side, roleTag] referenced by the matrix overlays and
// baseline patterns, resolve the concrete class pool and warn when it is empty
// against the live mod preset. This is the pre-flight check operators run
// before enabling ARC_incidentOverlaySpawnsEnabled. Read-only: the resolver
// only reads config and memoises a cache.
private _emptyPoolCount = 0;
if (!isNil "ARC_fnc_worldSpawnRoleResolve") then {
    private _seenRoles = [];
    private _checkRoleSpecs = {
        params ["_specs"];
        if (!(_specs isEqualType [])) exitWith {};
        {
            if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualType "" } && { (_x select 1) isEqualType "" }) then {
                private _roleTag = _x select 0;
                private _sideStr = _x select 1;
                private _key = format ["%1|%2", toLower _sideStr, toLower _roleTag];
                if (!(_key in _seenRoles)) then {
                    _seenRoles pushBack _key;
                    private _pool = [_sideStr, _roleTag] call ARC_fnc_worldSpawnRoleResolve;
                    if ((count _pool) == 0) then {
                        _emptyPoolCount = _emptyPoolCount + 1;
                        [format ["[CLASSPOOL] role '%1' side '%2' resolves to EMPTY class pool", _roleTag, _sideStr]] call _addWarn;
                    };
                };
            };
        } forEach _specs;
    };
    // Baseline purpose patterns.
    {
        private _pm = [[_purposePatterns, _x, []] call _hg] call _pairsToMap;
        [[_pm, "baselinePop", []] call _hg] call _checkRoleSpecs;
    } forEach ([_purposePatterns] call (compile "params ['_m']; keys _m"));
    // Incident / lead / civic overlays.
    {
        private _om = [[_incidentOverlays, _x, []] call _hg] call _pairsToMap;
        [[_om, "overlay", []] call _hg] call _checkRoleSpecs;
    } forEach ([_incidentOverlays] call (compile "params ['_m']; keys _m"));
    {
        private _om = [[_leadOverlays, _x, []] call _hg] call _pairsToMap;
        [[_om, "overlay", []] call _hg] call _checkRoleSpecs;
    } forEach ([_leadOverlays] call (compile "params ['_m']; keys _m"));
    {
        private _om = [[_civicMissionOverlays, _x, []] call _hg] call _pairsToMap;
        [[_om, "overlay", []] call _hg] call _checkRoleSpecs;
    } forEach ([_civicMissionOverlays] call (compile "params ['_m']; keys _m"));
};

// --- Building-purpose classification coverage (issue #633 step 5) ---------
// Read the server-local registry produced by ARC_fnc_worldBuildingPurposeClassify
// (present only when ARC_spawnPatternsEnabled and after the building-slot scan).
// Tally per-purpose location counts and warn on any location left unclassified.
private _buildingPurposeCounts = [];
private _bpReg = missionNamespace getVariable ["ARC_worldBuildingPurpose", createHashMap];
if (_bpReg isEqualType createHashMap && { (count _bpReg) > 0 }) then {
    private _tally = createHashMap;
    {
        private _tag = [_bpReg, _x, "NONE"] call _hg;
        if (!(_tag isEqualType "")) then { _tag = "NONE"; };
        private _cur = [_tally, _tag, 0] call _hg;
        if (!(_cur isEqualType 0)) then { _cur = 0; };
        _tally set [_tag, _cur + 1];
        if (_tag isEqualTo "NONE") then {
            [format ["[BUILDINGPURPOSE] location '%1' is unclassified (NONE) — no purpose mapping/hint/site match", _x]] call _addWarn;
        };
    } forEach ([_bpReg] call (compile "params ['_m']; keys _m"));
    {
        _buildingPurposeCounts pushBack [_x, [_tally, _x, 0] call _hg];
    } forEach ([_tally] call (compile "params ['_m']; keys _m"));
};

// --- Emit -----------------------------------------------------------------
private _summary = [count _rows, _locationCount, _siteTypeCount, _incidentRowCount, _civicRowCount, count _warnings];

diag_log format [
    "[ARC][SPAWNPAT][AUDIT] rows=%1 locations=%2 siteTypes=%3 incidents=%4 civic=%5 warnings=%6 emptyPools=%7",
    _summary select 0, _summary select 1, _summary select 2, _summary select 3, _summary select 4, _summary select 5, _emptyPoolCount
];

diag_log format ["[ARC][SPAWNPAT][AUDIT] buildingPurposeCounts=%1", _buildingPurposeCounts];

if (_verbose) then {
    {
        private _rm = [_x] call _pairsToMap;
        diag_log format [
            "[ARC][SPAWNPAT][ROW] %1 ref=%2 purpose=%3 type=%4 place=%5 ai=%6 obj=%7 cleanup=%8 warn=%9",
            [_rm, "kind", ""] call _hg,
            [_rm, "ref", ""] call _hg,
            [_rm, "purpose", ""] call _hg,
            [_rm, "incidentType", ""] call _hg,
            [_rm, "placement", ""] call _hg,
            [_rm, "aiRange", []] call _hg,
            [_rm, "objRange", []] call _hg,
            [_rm, "cleanupOwner", ""] call _hg,
            [_rm, "warnings", []] call _hg
        ];
    } forEach _rows;
    {
        diag_log format ["[ARC][SPAWNPAT][WARN] %1", _x];
    } forEach _warnings;
};

[
    ["rows", _rows],
    ["warnings", _warnings],
    ["summary", _summary],
    ["buildingPurposeCounts", _buildingPurposeCounts]
]
