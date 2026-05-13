/*
    ARC_fnc_threatVirtualPoolSnapshotBuild

    Server-only. Build read-only Virtual OpFor pool observability snapshot for
    operator/admin debug surfaces.

    Returns:
      ARRAY snapshot pairs (threat_virtual_opfor_obs_v1)
*/

if (!isServer) exitWith {[]};

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };
    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith {
            _idx = _forEachIndex;
        };
    } forEach _pairs;
    if (_idx < 0) exitWith { _default };
    private _entry = _pairs select _idx;
    private _value = _entry select 1;
    if (isNil "_value") exitWith { _default };
    _value
};

// Local helper intentionally kept in-file for this single snapshot builder scope
// to avoid cross-subsystem helper churn in this focused Epic 8 slice.
private _boolOrDefault = {
    params ["_value", "_default"];
    if ((_value isEqualType true) || (_value isEqualType false)) exitWith { _value };
    _default
};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
_enabled = [_enabled, true] call _boolOrDefault;

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _activeVgIndex = ["threat_v0_vgroup_active_index", []] call ARC_fnc_stateGet;
if (!(_activeVgIndex isEqualType [])) then { _activeVgIndex = []; };

private _poolMaxGroups = missionNamespace getVariable ["ARC_threatVirtualPoolMaxGroups", 96];
if (!(_poolMaxGroups isEqualType 0)) then { _poolMaxGroups = 96; };
_poolMaxGroups = (_poolMaxGroups max 8) min 400;

private _physicalMaxGroups = missionNamespace getVariable ["ARC_threatVirtualPhysicalMaxGroups", 8];
if (!(_physicalMaxGroups isEqualType 0)) then { _physicalMaxGroups = 8; };
_physicalMaxGroups = (_physicalMaxGroups max 0) min 64;

private _cityPhysicalMaxGroups = missionNamespace getVariable ["ARC_threatVirtualPhysicalMaxGroups_FarabadCity", 4];
if (!(_cityPhysicalMaxGroups isEqualType 0)) then { _cityPhysicalMaxGroups = 4; };
_cityPhysicalMaxGroups = (_cityPhysicalMaxGroups max 0) min _physicalMaxGroups;

private _spawnBudgetPerTick = missionNamespace getVariable ["ARC_threatVirtualSpawnBudgetPerTick", 2];
if (!(_spawnBudgetPerTick isEqualType 0)) then { _spawnBudgetPerTick = 2; };
_spawnBudgetPerTick = (_spawnBudgetPerTick max 0) min 16;

private _protectedZones = missionNamespace getVariable ["ARC_threatVirtualProtectedZones", ["Airbase", "GreenZone", "MilitaryBase"]];
if (!(_protectedZones isEqualType [])) then { _protectedZones = ["Airbase", "GreenZone", "MilitaryBase"]; };

private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
private _activeMarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
if (!(_activeMarker isEqualType "")) then { _activeMarker = ""; };

private _activeIncidentZone = "";
if (!(_activeMarker isEqualTo "")) then
{
    private _markerPos = getMarkerPos _activeMarker;
    if (_markerPos isEqualType [] && { (count _markerPos) >= 2 }) then
    {
        _activeIncidentZone = [_markerPos] call ARC_fnc_worldGetZoneForPos;
    };
};

private _virtualCount = 0;
private _dormantCount = 0;
private _activeCount = 0;
private _physicalCount = 0;
private _unknownStateCount = 0;
private _materializedAliveUnitCount = 0;
private _protectedIntersectionCount = 0;
private _physicalInProtectedCount = 0;
private _physicalGroupIds = [];
private _rowCap = 12;
private _materializedGroupRows = [];
private _materializedRowsTruncated = false;

{
    private _rec = _x;
    if (!(_rec isEqualType [])) then { continue; };

    private _type = [_rec, "type", ""] call _kvGet;
    // Only virtual OpFor records participate in this snapshot.
    if (!(_type isEqualTo "VIRTUAL_OPFOR")) then { continue; };

    _virtualCount = _virtualCount + 1;

    // Defensive normalization: runtime writes uppercase state strings, but snapshots
    // guard against mixed-case drift from legacy or hand-edited state.
    private _state = toUpper ([_rec, "state", "VIRTUAL_DORMANT"] call _kvGet);
    private _vgId = [_rec, "vgroup_id", ""] call _kvGet;
    private _pos = [_rec, "pos", []] call _kvGet;
    private _zone = "";
    if (_pos isEqualType [] && { (count _pos) >= 2 }) then
    {
        _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
    };

    if (_zone in _protectedZones) then
    {
        _protectedIntersectionCount = _protectedIntersectionCount + 1;
    };

    switch (_state) do
    {
        case "VIRTUAL_DORMANT":
        {
            _dormantCount = _dormantCount + 1;
        };
        case "VIRTUAL_ACTIVE":
        {
            _activeCount = _activeCount + 1;
        };
        case "PHYSICAL":
        {
            _physicalCount = _physicalCount + 1;
            _physicalGroupIds pushBackUnique _vgId;
            if (_zone in _protectedZones) then
            {
                _physicalInProtectedCount = _physicalInProtectedCount + 1;
            };

            private _spawned = [_rec, "spawnedUnits", []] call _kvGet;
            if (!(_spawned isEqualType [])) then { _spawned = []; };

            private _aliveUnits = 0;
            // Bounded by per-record spawned-unit refs; current runtime group strengths are
            // typically small (virtual pool defaults seed 2-5 units), so linear scan is acceptable.
            {
                private _u = objectFromNetId _x;
                if (!isNull _u && { alive _u }) then
                {
                    _aliveUnits = _aliveUnits + 1;
                };
            } forEach _spawned;

            _materializedAliveUnitCount = _materializedAliveUnitCount + _aliveUnits;

            if ((count _materializedGroupRows) < _rowCap) then
            {
                _materializedGroupRows pushBack [
                    ["vgroup_id", _vgId],
                    ["zone", _zone],
                    ["spawned_unit_refs_count", count _spawned],
                    ["alive_units", _aliveUnits],
                    ["last_player_near_ts", [_rec, "lastPlayerNearTs", -1] call _kvGet],
                    ["anchor_location_id", [_rec, "anchorLocationId", ""] call _kvGet],
                    ["anchor_location_name", [_rec, "anchorLocationName", ""] call _kvGet]
                ];
            } else {
                _materializedRowsTruncated = true;
            };
        };
        default
        {
            _unknownStateCount = _unknownStateCount + 1;
        };
    };
} forEach _records;

private _activeIndexOrphans = [];
{
    if (!(_x in _physicalGroupIds)) then
    {
        _activeIndexOrphans pushBack _x;
    };
} forEach _activeVgIndex;

private _loopRunning = missionNamespace getVariable ["ARC_virtualPoolLoopRunning", false];
_loopRunning = [_loopRunning, false] call _boolOrDefault;

private _lastThreatEvent = missionNamespace getVariable ["threat_v0_debug_last_event", []];
if (!(_lastThreatEvent isEqualType [])) then { _lastThreatEvent = []; };

private _economySnapshot = missionNamespace getVariable ["ARC_pub_threatEconomySnapshot", []];
if (!(_economySnapshot isEqualType [])) then { _economySnapshot = []; };
private _economySchema = [_economySnapshot, "schema", ""] call _kvGet;
if (!(_economySchema isEqualType "")) then { _economySchema = ""; };

private _threatUiSnapshotAt = missionNamespace getVariable ["ARC_pub_threatUiSnapshotUpdatedAt", -1];
if (!(_threatUiSnapshotAt isEqualType 0)) then { _threatUiSnapshotAt = -1; };

[
    ["v", 1],
    ["schema", "threat_virtual_opfor_obs_v1"],
    ["updatedAt", serverTime],
    ["summary", [
        ["enabled", _enabled],
        ["virtual_group_count", _virtualCount],
        ["materialized_group_count", _physicalCount],
        ["materialized_alive_unit_count", _materializedAliveUnitCount],
        ["active_index_count", count _activeVgIndex],
        ["active_index_orphan_count", count _activeIndexOrphans]
    ]],
    ["states", [
        ["virtual_dormant_count", _dormantCount],
        ["virtual_active_count", _activeCount],
        ["physical_count", _physicalCount],
        ["unknown_state_count", _unknownStateCount]
    ]],
    ["capacity", [
        ["pool_max_groups", _poolMaxGroups],
        ["physical_max_groups", _physicalMaxGroups],
        ["city_physical_max_groups", _cityPhysicalMaxGroups],
        ["spawn_budget_per_tick", _spawnBudgetPerTick]
    ]],
    ["protectedZones", [
        ["configured", _protectedZones],
        ["intersection_count", _protectedIntersectionCount],
        ["physical_in_protected_count", _physicalInProtectedCount],
        ["active_incident_zone", _activeIncidentZone],
        ["active_incident_in_protected_zone", _activeIncidentZone in _protectedZones]
    ]],
    ["materialization", [
        ["active_index_orphans", _activeIndexOrphans],
        ["materialized_group_row_cap", _rowCap],
        ["materialized_group_rows_truncated", _materializedRowsTruncated],
        ["materialized_group_rows", _materializedGroupRows]
    ]],
    ["locality", [
        ["authority", "server"],
        ["isServerContext", isServer],
        ["loop_running", _loopRunning],
        ["shared_state_keys", ["threat_v0_records", "threat_v0_vgroup_active_index"]]
    ]],
    ["integration", [
        ["active_task_id", _activeTaskId],
        ["active_incident_marker", _activeMarker],
        ["threat_last_event", _lastThreatEvent],
        ["economy_snapshot_schema", _economySchema],
        ["threat_ui_snapshot_updated_at", _threatUiSnapshotAt]
    ]],
    ["roleBoundaries", [
        ["read_only", true],
        ["admin_control_surface", "deferred"]
    ]]
]
