/*
    Build/publish a read-only S1 registry snapshot for clients.

    In v2 format, each group record is augmented with pre-aggregated stats
    (paxCount, activePax, kiaPax, avgReadiness) and classification fields
    (s1TopCategory, s1SubCategory, s1EchelonDepth, s1CompanyLetter,
    s1ParentEchelonStr) so clients can build the echelon tree without
    iterating the full unit list.

    Category-level roll-up stats are published in a separate "catStats" array.

    Params:
      0: BOOL - publish snapshot into ARC_pub_s1_registry (default true)

    Returns:
      ARRAY - snapshot pairs array
*/

params [["_publish", true, [true]]];

private _registry = missionNamespace getVariable ["ARC_s1_registry", []];
if (!(_registry isEqualType [])) then { _registry = []; };

// Extract groups and units from the flat registry
private _groups = [];
private _units = [];
{
    if (!(_x isEqualType [])) then { continue; };
    if ((count _x) < 2) then { continue; };
    private _k = _x select 0;
    private _v = _x select 1;
    if (_k isEqualTo "groups" && { _v isEqualType [] }) then { _groups = _v; };
    if (_k isEqualTo "units"  && { _v isEqualType [] }) then { _units  = _v; };
} forEach _registry;

// --- Helper: get a field value from a pairs record ---
private _getPair = {
    params ["_rec", "_key", "_def"];
    private _result = _def;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith {
            _result = _x select 1;
        };
    } forEach _rec;
    _result
};

// --- Pre-build unit stats keyed by groupId ---
// bucket: [groupId, paxCount, activePax, kiaPax, readinessSum]
private _groupStats = [];

{
    if (!(_x isEqualType [])) then { continue; };
    private _gid = [_x, "groupId", ""] call _getPair;
    if (!(_gid isEqualType "") || { _gid isEqualTo "" }) then { continue; };
    private _vs = [_x, "virtualStatus", "UNKNOWN"] call _getPair;
    if (!(_vs isEqualType "")) then { _vs = "UNKNOWN"; };
    private _rd = [_x, "readiness", 0] call _getPair;
    if (!(_rd isEqualType 0)) then { _rd = 0; };

    private _isActive = _vs isEqualTo "ACTIVE";
    private _isKia    = _vs isEqualTo "KIA";

    private _bucketIdx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x select 0) isEqualTo _gid) }) exitWith {
            _bucketIdx = _forEachIndex;
        };
    } forEach _groupStats;

    if (_bucketIdx < 0) then {
        _groupStats pushBack [_gid, 0, 0, 0, 0];
        _bucketIdx = (count _groupStats) - 1;
    };

    private _bucket = _groupStats select _bucketIdx;
    _groupStats set [_bucketIdx, [
        _gid,
        (_bucket select 1) + 1,
        (_bucket select 2) + (if (_isActive) then {1} else {0}),
        (_bucket select 3) + (if (_isKia) then {1} else {0}),
        (_bucket select 4) + _rd
    ]];
} forEach _units;

// --- Augment each group record with stats + classification ---
private _augmentedGroups = [];
{
    if (!(_x isEqualType [])) then { continue; };
    if (!(_gid isEqualType "") || { _gid isEqualTo "" }) then { continue; };

    private _pe       = [_x, "parentEchelon", ""] call _getPair;
    private _callsign = [_x, "callsign", ""]       call _getPair;

    private _classify = [_pe, _callsign] call ARC_fnc_s1EchelonClassify;
    private _topCat   = _classify select 0;
    private _subCat   = _classify select 1;
    private _depth    = _classify select 2;
    private _coLetter = _classify select 3;
    private _parentPe = _classify select 4;

    private _paxCount  = 0;
    private _activePax = 0;
    private _kiaPax    = 0;
    private _rdSum     = 0;
    {
        if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x select 0) isEqualTo _gid) }) exitWith {
            _paxCount  = _x select 1;
            _activePax = _x select 2;
            _kiaPax    = _x select 3;
            _rdSum     = _x select 4;
        };
    } forEach _groupStats;
    private _avgReadiness = if (_paxCount > 0) then { _rdSum / _paxCount } else { 0 };

    private _aug = +_x;
    _aug pushBack ["s1TopCategory",      _topCat];
    _aug pushBack ["s1SubCategory",      _subCat];
    _aug pushBack ["s1EchelonDepth",     _depth];
    _aug pushBack ["s1CompanyLetter",    _coLetter];
    _aug pushBack ["s1ParentEchelonStr", _parentPe];
    _aug pushBack ["s1PaxCount",         _paxCount];
    _aug pushBack ["s1ActivePax",        _activePax];
    _aug pushBack ["s1KiaPax",           _kiaPax];
    _aug pushBack ["s1AvgReadiness",     _avgReadiness];

    _augmentedGroups pushBack _aug;
} forEach _groups;

// --- Build category aggregate stats ---
private _catOrder = [
    "JTF FARABAD",
    "TF REDFALCON",
    "USAF / AIRBASE",
    "SUPPORT / BSB",
    "BSTB",
    "AVIATION",
    "HOST NATION",
    "OTHER"
];
private _catStats = [];
{
    _catStats pushBack [_x, 0, 0, 0, 0, 0];
} forEach _catOrder;

{
    if (!(_x isEqualType [])) then { continue; };
    private _topCat = [_x, "s1TopCategory",  "OTHER"] call _getPair;
    private _pax    = [_x, "s1PaxCount",     0]       call _getPair;
    private _active = [_x, "s1ActivePax",    0]       call _getPair;
    private _kia    = [_x, "s1KiaPax",       0]       call _getPair;
    private _rd     = [_x, "s1AvgReadiness", 0]       call _getPair;

    private _catIdx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 6 } && { ((_x select 0) isEqualTo _topCat) }) exitWith {
            _catIdx = _forEachIndex;
        };
    } forEach _catStats;

    if (_catIdx < 0) then {
        _catStats pushBack [_topCat, 0, 0, 0, 0, 0];
        _catIdx = (count _catStats) - 1;
    };

    private _cs = _catStats select _catIdx;
    _catStats set [_catIdx, [
        _topCat,
        (_cs select 1) + _pax,
        (_cs select 2) + _active,
        (_cs select 3) + _kia,
        (_cs select 4) + _rd,
        (_cs select 5) + 1
    ]];
} forEach _augmentedGroups;

// --- Assemble v2 snapshot ---
private _now = serverTime;
private _snapshot = [
    ["schema",    "s1_tree_v2"],
    ["updatedAt", _now],
    ["groups",    _augmentedGroups],
    ["catStats",  _catStats],
    ["catOrder",  _catOrder],
    ["units",     _units]
];

if (_publish && { isServer }) then {
    missionNamespace setVariable ["ARC_pub_s1_registry",          _snapshot, true];
    missionNamespace setVariable ["ARC_pub_s1_registryUpdatedAt", _now,      true];
    missionNamespace setVariable ["ARC_pub_s1_registryMeta",      ["s1RegistrySnapshot", _now]];
};

_snapshot
