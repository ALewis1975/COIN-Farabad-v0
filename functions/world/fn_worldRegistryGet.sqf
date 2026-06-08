/*
    ARC_fnc_worldRegistryGet

    Read-only World Registry adapter.

    Mode C intent: normalize access to existing world-derived state without
    changing world scans, objective scoring, marker creation, terrain data,
    or any existing consumer behavior.

    Returns: HASHMAP
*/

private _asPos3 = {
    params [ ["_pos", [], [[]]] ];
    private _p = +_pos;
    if ((count _p) < 2) exitWith { [] };
    if ((count _p) == 2) then { _p pushBack 0; };
    _p
};

private _named = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_named isEqualType [])) then { _named = []; };

private _sites = missionNamespace getVariable ["ARC_worldTerrainSites", []];
if (!(_sites isEqualType [])) then { _sites = []; };

private _zones = missionNamespace getVariable ["ARC_worldZones", []];
if (!(_zones isEqualType [])) then { _zones = []; };

private _aliases = missionNamespace getVariable ["ARC_markerAliases", createHashMap];
if (!(_aliases isEqualType createHashMap)) then { _aliases = createHashMap; };

private _objectiveIndex = missionNamespace getVariable ["ARC_worldObjectiveIndex", createHashMap];
if (!(_objectiveIndex isEqualType createHashMap)) then { _objectiveIndex = createHashMap; };

private _objectiveRanked = missionNamespace getVariable ["ARC_worldObjectiveRanked", []];
if (!(_objectiveRanked isEqualType [])) then { _objectiveRanked = []; };

private _locationsOut = [];
private _allMarkers = allMapMarkers;
{
    _x params [ ["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]] ];
    private _p = [_pos] call _asPos3;
    if (_id isEqualTo "" || { (count _p) == 0 }) then { continue; };

    private _marker = format ["ARC_loc_%1", _id];
    private _rec = createHashMap;
    _rec set ["id", _id];
    _rec set ["displayName", _displayName];
    _rec set ["pos", _p];
    _rec set ["marker", _marker];
    _rec set ["markerExists", _marker in _allMarkers];
    _locationsOut pushBack _rec;
} forEach _named;

private _sitesOut = [];
{
    _x params [ ["_siteType", "", [""]], ["_positions", [], [[]]] ];
    if (_siteType isEqualTo "") then { continue; };

    private _posOut = [];
    {
        private _p = [_x] call _asPos3;
        if ((count _p) > 0) then { _posOut pushBack _p; };
    } forEach _positions;

    private _rec = createHashMap;
    _rec set ["type", _siteType];
    _rec set ["count", count _posOut];
    _rec set ["positions", _posOut];
    _sitesOut pushBack _rec;
} forEach _sites;

private _zonesOut = [];
private _allMarkersZ = allMapMarkers;
{
    _x params [
        ["_id", "", [""]],
        ["_displayName", "", [""]],
        ["_center", [], [[]]],
        ["_halfExtents", [], [[]]],
        ["_dir", 0, [0]]
    ];
    private _p = [_center] call _asPos3;
    if (_id isEqualTo "" || { (count _p) == 0 }) then { continue; };

    private _marker = format ["ARC_zone_%1", _id];
    private _rec = createHashMap;
    _rec set ["id", _id];
    _rec set ["displayName", _displayName];
    _rec set ["center", _p];
    _rec set ["halfExtents", +_halfExtents];
    _rec set ["dir", _dir];
    _rec set ["marker", _marker];
    _rec set ["markerExists", _marker in _allMarkersZ];
    _zonesOut pushBack _rec;
} forEach _zones;

private _aliasesOut = [];
{
    _aliasesOut pushBack [_x, _aliases get _x];
} forEach (keys _aliases);

private _objectiveIndexOut = [];
{
    _objectiveIndexOut pushBack [_x, _objectiveIndex get _x];
} forEach (keys _objectiveIndex);

private _counts = createHashMap;
_counts set ["locations", count _locationsOut];
_counts set ["terrainSiteTypes", count _sitesOut];
_counts set ["zones", count _zonesOut];
_counts set ["aliases", count _aliasesOut];
_counts set ["objectiveIndex", count _objectiveIndexOut];
_counts set ["objectiveRanked", count _objectiveRanked];

private _out = createHashMap;
_out set ["schema", "ARC_worldRegistry_v1"];
_out set ["version", [1,0,0]];
_out set ["builtAtServerTime", serverTime];
_out set ["source", "ARC_worldRegistry_adapter"];
_out set ["locations", _locationsOut];
_out set ["terrainSites", _sitesOut];
_out set ["zones", _zonesOut];
_out set ["markerAliases", _aliasesOut];
_out set ["objectiveIndex", _objectiveIndexOut];
_out set ["objectiveRanked", +_objectiveRanked];
_out set ["counts", _counts];
_out set ["anchorIssues", []];
_out
