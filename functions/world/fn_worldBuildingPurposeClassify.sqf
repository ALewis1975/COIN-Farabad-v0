/*
    ARC_fnc_worldBuildingPurposeClassify

    Server-only. Per-building/per-location purpose classification layer for the
    spawn-pattern system (issue #633 step 5). Assigns a purpose tag
    (RESIDENTIAL | MARKET | RELIGIOUS | ... | CONSTRUCTION | MSR_ROAD | NONE) to
    every named location that has pre-scanned building slots, so slot-bound
    overlay placement (indoor / rooftop) can stay locally coherent with what the
    place is supposed to be.

    Reuses the existing server-local registries (NO new scans):
        ARC_worldBuildingSlots  (locationId -> [bldPositions, roadsidePositions])
        ARC_worldNamedLocations (locationId, displayName, pos)
        ARC_worldTerrainSites   (siteType, [positions...])
    and the data-driven matrix data/farabad_spawn_patterns.sqf
        locationPurposes  (locationId -> purposeTag)
        siteTypePurposes  (terrainSiteType -> purposeTag)
        buildingClassPurposeHints (substring -> purposeTag, marker-name signals)

    Classification, cheapest-first (issue #633 step 5):
        1. Explicit named-location mapping (locationPurposes).
        2. Marker-name signal override (buildingClassPurposeHints) — lets an
           "...construction..."/"...unfinished..." location resolve to
           CONSTRUCTION even if otherwise mapped.
        3. Nearest terrain site type (siteTypePurposes) when still unmapped.
        4. NONE sentinel otherwise (reported as a warning by the audit).

    State written (server missionNamespace, NOT replicated, NOT persisted):
        ARC_worldBuildingPurpose (HashMap) locationId -> purposeTag STRING

    Gated by ARC_spawnPatternsEnabled so it is inert when the spawn-pattern
    system is off (gameplay-neutral default). Must run AFTER
    ARC_fnc_worldScanBuildingSlots has populated ARC_worldBuildingSlots.

    Params: none.
    Returns: NUMBER - count of locations classified (0 when gated off / no slots).
*/

if (!isServer) exitWith {0};

private _enabled = missionNamespace getVariable ["ARC_spawnPatternsEnabled", false];
if (!(_enabled isEqualType true) || { !_enabled }) exitWith {0};

private _slots = missionNamespace getVariable ["ARC_worldBuildingSlots", createHashMap];
if (!(_slots isEqualType createHashMap) || { (count _slots) == 0 }) exitWith {
    diag_log "[ARC][SPAWNPAT][WARN] ARC_fnc_worldBuildingPurposeClassify: ARC_worldBuildingSlots empty — run after worldScanBuildingSlots.";
    0
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn = compile "params ['_m']; keys _m";
private _pairsToMap = {
    params ["_pairs"];
    private _m = createHashMap;
    if (!(_pairs isEqualType [])) exitWith { _m };
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then { _m set [_x select 0, _x select 1]; };
    } forEach _pairs;
    _m
};

// --- Load the matrix purpose tables --------------------------------------
private _fileExistsFn = compile "params ['_p']; fileExists _p";
private _patPath = "data\farabad_spawn_patterns.sqf";
private _locationPurposes = createHashMap;
private _siteTypePurposes = createHashMap;
private _classHints = createHashMap;
if ([_patPath] call _fileExistsFn) then {
    private _raw = call compile preprocessFileLineNumbers _patPath;
    if (_raw isEqualType []) then {
        private _root = [_raw] call _pairsToMap;
        _locationPurposes = [[_root, "locationPurposes", []] call _hg] call _pairsToMap;
        _siteTypePurposes = [[_root, "siteTypePurposes", []] call _hg] call _pairsToMap;
        _classHints       = [[_root, "buildingClassPurposeHints", []] call _hg] call _pairsToMap;
    };
} else {
    diag_log "[ARC][SPAWNPAT][WARN] ARC_fnc_worldBuildingPurposeClassify: data\farabad_spawn_patterns.sqf missing.";
};

private _named = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_named isEqualType [])) then { _named = []; };
private _terrainSites = missionNamespace getVariable ["ARC_worldTerrainSites", []];
if (!(_terrainSites isEqualType [])) then { _terrainSites = []; };

// locationId -> pos lookup (for nearest-terrain-site fallback).
private _locPos = createHashMap;
{
    if (_x isEqualType [] && { (count _x) >= 3 }) then {
        private _lid = _x select 0;
        private _lp  = _x select 2;
        if (_lid isEqualType "" && { _lp isEqualType [] }) then { _locPos set [_lid, _lp]; };
    };
} forEach _named;

// Nearest terrain site type to a position (bounded: one pass over site groups).
private _nearestSiteType = {
    params ["_pos"];
    private _best = ""; private _bestD = 1e9;
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then {
            private _st = _x select 0;
            private _ps = _x select 1;
            if (_st isEqualType "" && { _ps isEqualType [] }) then {
                {
                    if (_x isEqualType [] && { (count _x) >= 2 }) then {
                        private _d = _pos distance2D _x;
                        if (_d < _bestD) then { _bestD = _d; _best = _st; };
                    };
                } forEach _ps;
            };
        };
    } forEach _terrainSites;
    [_best, _bestD]
};

// --- Classify every location that has scanned building slots --------------
private _purpose = createHashMap;       // locationId -> purposeTag
private _purposeCounts = createHashMap; // purposeTag -> [locationCount, bldSlotCount]
private _noneCount = 0;

private _bumpCount = {
    params ["_counts", "_tag", "_bldN"];
    private _cur = [_counts, _tag, [0, 0]] call _hg;
    if (!(_cur isEqualType [])) then { _cur = [0, 0]; };
    _counts set [_tag, [(_cur select 0) + 1, (_cur select 1) + _bldN]];
};

private _siteFallbackMaxM = 250;

{
    private _lid = _x;
    private _entry = [_slots, _lid, []] call _hg;
    private _bldN = 0;
    if (_entry isEqualType [] && { (count _entry) >= 1 } && { (_entry select 0) isEqualType [] }) then {
        _bldN = count (_entry select 0);
    };

    // 1. Explicit named-location mapping.
    private _tag = [_locationPurposes, _lid, ""] call _hg;
    if (!(_tag isEqualType "")) then { _tag = ""; };

    // 2. Marker-name signal override (substring match).
    private _name = _lid;
    private _disp = "";
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _lid }) exitWith {
            _disp = _x select 1;
        };
    } forEach _named;
    private _nameL = toLower (_name + " " + (if (_disp isEqualType "") then { _disp } else { "" }));
    {
        private _sub = _x;
        if (_sub isEqualType "" && { (_nameL find (toLower _sub)) >= 0 }) exitWith {
            private _hintTag = [_classHints, _sub, ""] call _hg;
            if (_hintTag isEqualType "" && { !(_hintTag isEqualTo "") }) then { _tag = _hintTag; };
        };
    } forEach ([_classHints] call _keysFn);

    // 3. Nearest terrain site type fallback when still unmapped.
    if (_tag isEqualTo "") then {
        private _lp = [_locPos, _lid, []] call _hg;
        if (_lp isEqualType [] && { (count _lp) >= 2 }) then {
            private _res = [_lp] call _nearestSiteType;
            private _st = _res select 0;
            private _stD = _res select 1;
            if (!(_st isEqualTo "") && { _stD <= _siteFallbackMaxM }) then {
                private _stTag = [_siteTypePurposes, _st, ""] call _hg;
                if (_stTag isEqualType "" && { !(_stTag isEqualTo "") }) then { _tag = _stTag; };
            };
        };
    };

    // 4. NONE sentinel otherwise.
    if (_tag isEqualTo "") then { _tag = "NONE"; _noneCount = _noneCount + 1; };

    _purpose set [_lid, _tag];
    [_purposeCounts, _tag, _bldN] call _bumpCount;
} forEach ([_slots] call _keysFn);

missionNamespace setVariable ["ARC_worldBuildingPurpose", _purpose]; // server-local only; no broadcast

private _classified = count _purpose;
diag_log format [
    "[ARC][SPAWNPAT][INFO] ARC_fnc_worldBuildingPurposeClassify: classified %1 location(s); unclassified(NONE)=%2.",
    _classified, _noneCount
];

_classified
