/*
    ARC_fnc_civsubCivCleanupTick

    Cleans registry and despawns civs that are null or outside active districts.
    Hotfix02 (KeepBodies): dead civ bodies remain in-world; we only remove them from the active registry.
    Processes a bounded number of despawns per tick.
*/

if (!isServer) exitWith {
    diag_log "[CIVSUB][CIVS][CLEANUP] GUARD FAIL not_server";
    false
};
if !(missionNamespace getVariable ["civsub_v1_civs_enabled", false]) exitWith {
    diag_log "[CIVSUB][CIVS][CLEANUP] GUARD FAIL civsub_v1_civs_enabled=false";
    false
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn = compile "params ['_m']; keys _m";

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

private _active = missionNamespace getVariable ["civsub_v1_activeDistrictIds", []];
if !(_active isEqualType []) then { _active = []; };

private _q = missionNamespace getVariable ["civsub_v1_civ_despawnQueue", []];
if !(_q isEqualType []) then { _q = []; };

// Bounded, server-local diagnostic snapshot (replaced each tick; never persisted).
private _protectedCount = 0;
private _processedCount = 0;
private _deletedCount = 0;
private _retainedCount = 0;
private _samples = [];

// Scan registry for invalid or out-of-scope
{
    private _k = _x;
    private _row = [_reg, _k, createHashMap] call _hg;
    if !(_row isEqualType createHashMap) then {
        _reg deleteAt _k;
    } else {
        private _u = [_row, "unit", objNull] call _hg;
        private _did = [_row, "districtId", ""] call _hg;

        if (isNull _u) then {
            _reg deleteAt _k;
        } else {
            if (!alive _u) then {
                // Keep body in-world; remove from active registry (caps). Tag for future morgue automation.
                _u setVariable ["civsub_v1_dead", true, true];
                _u setVariable ["civsub_v1_dead_ts", serverTime, true];
                _u setVariable ["civsub_v1_dead_districtId", _did, true];
                _reg deleteAt _k;
            } else {
                // If district is no longer active, queue for despawn (living only)
                private _protected = [_u] call ARC_fnc_civsubCivIsProtected;
                if (_protected) then { _protectedCount = _protectedCount + 1; };
                if (!(_did in _active) && { !_protected }) then {
                    _q pushBackUnique _k;
                };
            };
        };
    };
} forEach ([_reg] call _keysFn);

// Process a bounded number per tick to avoid spikes
private _max = 6;
private _n = count _q;
if (_n > 0) then
{
    private _take = _max;
    if (_n < _take) then { _take = _n; };

    for "_i" from 0 to (_take - 1) do
    {
        private _k = _q deleteAt 0;
        private _row = [_reg, _k, createHashMap] call _hg;
        private _remove = true;
        _processedCount = _processedCount + 1;
        if (_row isEqualType createHashMap) then {
            private _u = [_row, "unit", objNull] call _hg;
            if (!isNull _u) then {
                private _uid = _u getVariable ["civ_uid", ""];
                private _localTask = _u getVariable ["ARC_localSupportTaskId", ""];
                private _overlayTask = _u getVariable ["ARC_overlayTaskId", ""];
                private _grid = mapGridPosition (getPosATL _u);
                _remove = [_u] call ARC_fnc_civsubCivDespawnUnit;
                private _outcome = if (_remove) then { "DELETED" } else { "RETAINED" };
                _samples pushBack [_k, _outcome, _uid, _localTask, _overlayTask, _grid];
                if (_remove) then {
                    _deletedCount = _deletedCount + 1;
                } else {
                    _retainedCount = _retainedCount + 1;
                    diag_log format [
                        "[CIVSUB][CIVS][CLEANUP] RETAIN ts=%1 actor=SERVER netId=%2 civ_uid=%3 localTask=%4 overlayTask=%5 grid=%6 reason=DELETION_REFUSED",
                        serverTime, _k, _uid, _localTask, _overlayTask, _grid
                    ];
                };
            };
        };
        // Drop the consumed queue entry, but never orphan a retained live actor.
        if (_remove) then { _reg deleteAt _k; };
    };
};

missionNamespace setVariable ["civsub_v1_civ_registry", _reg, true];
missionNamespace setVariable ["civsub_v1_civ_despawnQueue", _q, true];
missionNamespace setVariable ["civsub_v1_civ_cleanup_last_ts", serverTime, true];
missionNamespace setVariable [
    "civsub_v1_civ_cleanup_snapshot",
    [1, serverTime, count _reg, count _q, _protectedCount, _processedCount, _deletedCount, _retainedCount, _samples],
    false
];

true
